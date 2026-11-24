#include "totvs.ch"
#include "rptdef.ch"
#include "fwprintsetup.ch"

// Constantes de alinhamento do FWMSPrinter:nAlignHorz / SayAlign
#define PAD_LEFT    0
#define PAD_RIGHT   1
#define PAD_CENTER  2

// Limite vertical antes do Bloco 8 (Rodapé Fixo) em pixels/pontos do FWMSPrinter (A4 Portrait ~842pt)
#define LIMIT_FOOTER 700
#define PAGE_WIDTH   575
#define MARGIN_LEFT  20
#define MARGIN_RIGHT 575

/*/{Protheus.doc} RELPCP01
Relatório Gráfico de Ordem de Produção (OP) utilizando FWMSPrinter.
Pode ser acionado via Menu (com filtro ParamBox) ou diretamente posicionado no browse do MATA650 (SC2).
@type user function
@author Arquiteto Protheus
@since 23/11/2026
@version 12.1.2410
@param [lFromM650], logical, Indica se a chamada partiu diretamente da rotina MATA650 posicionada na SC2
@return logical, .T. se o processamento foi concluído
@table SC2, SB1, SC5, SA1, SA7, SD4, SG2, SH1
/*/
User Function RELPCP01(lFromM650)
    Local aArea      := GetArea()
    Local aAreaSC2   := SC2->(GetArea())
    Local cOpDe      := ""
    Local cOpAte     := ""
    Local dDataDe    := CtoD("")
    Local dDataAte   := CtoD("")
    Local lContinua  := .T.
    Local lPosM650   := .F.

    Default lFromM650 := .F.

    // Verifica se foi chamado diretamente do MATA650 com registro posicionado na SC2
    If lFromM650 .Or. (FunName() == "MATA650" .And. Select("SC2") > 0 .And. !SC2->(Eof()) .And. !SC2->(Bof()))
        If MsgYesNo("Deseja imprimir apenas a Ordem de Produção posicionada (" + ;
                    AllTrim(SC2->C2_NUM + SC2->C2_ITEM + SC2->C2_SEQUEN) + ")?" + CRLF + ;
                    "Clique em 'Não' para abrir o filtro por parâmetros.", "Imprimir OP - RELPCP01")
            lPosM650 := .T.
            cOpDe    := SC2->C2_NUM + SC2->C2_ITEM + SC2->C2_SEQUEN
            cOpAte   := SC2->C2_NUM + SC2->C2_ITEM + SC2->C2_SEQUEN
            dDataDe  := SC2->C2_EMISSAO
            dDataAte := SC2->C2_EMISSAO
        EndIf
    EndIf

    // Caso chamado via Menu ou usuário optou por filtrar intervalo via ParamBox
    If !lPosM650
        lContinua := AskParams(@cOpDe, @cOpAte, @dDataDe, @dDataAte)
    EndIf

    If lContinua
        // Importante: NÃO envolver FWMSPrinter:Preview() dentro de FwMsgRun(), pois o fechamento
        // do diálogo modal concorrente do FwMsgRun derruba o SmartClient após fechar o PDF.
        ProcRelOP(cOpDe, cOpAte, dDataDe, dDataAte)
    EndIf

    RestArea(aAreaSC2)
    RestArea(aArea)
Return lContinua

/*/{Protheus.doc} AskParams
Exibe ParamBox para coleta dos parâmetros de filtro da Ordem de Produção.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param cOpDe, character, Recebe por referência a OP Inicial (Num+Item+Sequen - 11 posições)
@param cOpAte, character, Recebe por referência a OP Final (Num+Item+Sequen - 11 posições)
@param dDataDe, date, Recebe por referência a Data de Emissão Inicial
@param dDataAte, date, Recebe por referência a Data de Emissão Final
@return logical, .T. se o usuário confirmou os parâmetros
/*/
Static Function AskParams(cOpDe, cOpAte, dDataDe, dDataAte)
    Local aPergs   := {}
    Local aRet     := {}
    Local lOk      := .F.
    Local nTamOP   := TamSX3("C2_NUM")[1] + TamSX3("C2_ITEM")[1] + TamSX3("C2_SEQUEN")[1]
    Local cInitDe  := Space(nTamOP)
    Local cInitAte := Replicate("Z", nTamOP)
    Local dInitDe  := FirstDate(dDataBase)
    Local dInitAte := LastDate(dDataBase)

    aAdd(aPergs, {1, "Ordem de Produção De",  cInitDe,  "@!", ".T.", "SC2", ".T.", 80, .F.})
    aAdd(aPergs, {1, "Ordem de Produção Até", cInitAte, "@!", ".T.", "SC2", ".T.", 80, .T.})
    aAdd(aPergs, {1, "Data de Emissão De",    dInitDe,  "",   ".T.", "",    ".T.", 60, .T.})
    aAdd(aPergs, {1, "Data de Emissão Até",   dInitAte, "",   ".T.", "",    ".T.", 60, .T.})

    If ParamBox(aPergs, "Parâmetros - Impressão de OP", @aRet, , , .T., , , , "RELPCP01", .T., .T.)
        cOpDe    := aRet[1]
        cOpAte   := aRet[2]
        dDataDe  := aRet[3]
        dDataAte := aRet[4]
        lOk      := .T.
    EndIf
Return lOk

/*/{Protheus.doc} ProcRelOP
Configura o objeto FWMSPrinter, executa a query principal (SC2) via BeginSql e coordena a impressão das OPs.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param cOpDe, character, OP Inicial
@param cOpAte, character, OP Final
@param dDataDe, date, Data de Emissão Inicial
@param dDataAte, date, Data de Emissão Final
@return nil, Sem retorno
@table SC2, SB1, SC5, SA1, SA7
/*/
Static Function ProcRelOP(cOpDe, cOpAte, dDataDe, dDataAte)
    Local cAliasSC2  := GetNextAlias()
    Local cFileName  := "OP_" + DtoS(Date()) + "_" + StrTran(Time(), ":", "") + ".rel"
    Local cPathPDF   := GetTempPath()
    Local cLogo      := ""
    Local cDataDe    := DtoS(dDataDe)
    Local cDataAte   := DtoS(dDataAte)
    Local cLoteField := "%' ' AS C2_XLOTE%"
    Local lAdjustLeg := .F.
    Local lDisabSet  := .T.
    Local nPag       := 0
    Local nRow       := 0
    Local oPrinter   := Nil
    Local oFonts     := JsonObject():New()
    Local oBrushGray := Nil

    // Verifica dinamicamente se existe campo de lote na SC2 (ex: C2_XLOTE ou C2_LOTECTL) para evitar ORA-00904
    If SC2->(FieldPos("C2_XLOTE")) > 0
        cLoteField := "%SC2.C2_XLOTE AS C2_XLOTE%"
    ElseIf SC2->(FieldPos("C2_LOTECTL")) > 0
        cLoteField := "%SC2.C2_LOTECTL AS C2_XLOTE%"
    EndIf

    // 1. Consulta principal na SC2 com JOIN em SB1, SC5, SA1 e SA7 utilizando BeginSql (100% compatível com Oracle/MSSQL/Postgres)
    // Campos customizados da SB1 incluídos: B1_XCAVID, B1_XCICLO, B1_XMOLDE, B1_XALTMOL, B1_XLARMOL, B1_XCOMMOL
    BeginSql Alias cAliasSC2
        Column C2_EMISSAO As Date
        Column C2_DATPRF  As Date

        SELECT
            SC2.C2_FILIAL,
            SC2.C2_NUM,
            SC2.C2_ITEM,
            SC2.C2_SEQUEN,
            SC2.C2_ITEMGRD,
            SC2.C2_PRODUTO,
            SC2.C2_QUANT,
            SC2.C2_UM,
            SC2.C2_EMISSAO,
            SC2.C2_DATPRF,
            SC2.C2_PEDIDO,
            SC2.C2_ITEMPV,
            SC2.C2_ROTEIRO,
            %Exp:cLoteField%,
            SB1.B1_DESC,
            SB1.B1_QE,
            SB1.B1_PESO,
            SB1.B1_PESBRU,
            SB1.B1_XCAVID,
            SB1.B1_XCICLO,
            SB1.B1_XMOLDE,
            SB1.B1_XALTMOL,
            SB1.B1_XLARMOL,
            SB1.B1_XCOMMOL,
            COALESCE(SC5.C5_CLIENTE, ' ') AS C5_CLIENTE,
            COALESCE(SC5.C5_LOJACLI, ' ') AS C5_LOJACLI,
            COALESCE(SA1.A1_NREDUZ,  ' ') AS A1_NREDUZ,
            COALESCE(SA1.A1_NOME,    ' ') AS A1_NOME,
            COALESCE(SA7.A7_CODCLI,  ' ') AS A7_CODCLI
        FROM %table:SC2% SC2
        INNER JOIN %table:SB1% SB1
            ON  SB1.B1_FILIAL  = %xFilial:SB1%
            AND SB1.B1_COD     = SC2.C2_PRODUTO
            AND SB1.%notDel%
        LEFT JOIN %table:SC5% SC5
            ON  SC5.C5_FILIAL  = %xFilial:SC5%
            AND SC5.C5_NUM     = SC2.C2_PEDIDO
            AND SC5.%notDel%
        LEFT JOIN %table:SA1% SA1
            ON  SA1.A1_FILIAL  = %xFilial:SA1%
            AND SA1.A1_COD     = SC5.C5_CLIENTE
            AND SA1.A1_LOJA    = SC5.C5_LOJACLI
            AND SA1.%notDel%
        LEFT JOIN %table:SA7% SA7
            ON  SA7.A7_FILIAL  = %xFilial:SA7%
            AND SA7.A7_CLIENTE = SC5.C5_CLIENTE
            AND SA7.A7_LOJA    = SC5.C5_LOJACLI
            AND SA7.A7_PRODUTO = SC2.C2_PRODUTO
            AND SA7.%notDel%
        WHERE SC2.C2_FILIAL = %xFilial:SC2%
          AND (SC2.C2_NUM || SC2.C2_ITEM || SC2.C2_SEQUEN) BETWEEN %Exp:cOpDe% AND %Exp:cOpAte%
          AND SC2.C2_EMISSAO BETWEEN %Exp:cDataDe% AND %Exp:cDataAte%
          AND SC2.%notDel%
        ORDER BY SC2.C2_FILIAL, SC2.C2_NUM, SC2.C2_ITEM, SC2.C2_SEQUEN
    EndSql

    If (cAliasSC2)->(Eof())
        (cAliasSC2)->(DbCloseArea())
        MsgInfo("Nenhuma Ordem de Produção encontrada para os parâmetros informados.", "Atenção - RELPCP01")
        Return
    EndIf

    // 2. Obtém o logotipo da empresa (procura no servidor e copia para o cliente via CpyS2T)
    cLogo := GetLogoOP()

    // 3. Inicializa o objeto FWMSPrinter direto para geração de PDF (sem conflito de Setup modal)
    oPrinter := FWMSPrinter():New(cFileName, IMP_PDF, lAdjustLeg, cPathPDF, lDisabSet)
    oPrinter:SetResolution(72)
    oPrinter:SetPortrait()
    oPrinter:SetPaperSize(DMPAPER_A4)
    oPrinter:SetMargin(10, 10, 10, 10)
    oPrinter:cPathPDF := cPathPDF
    oPrinter:SetViewPDF(.T.)

    // 4. Cria fontes padronizadas e brush cinza claro para cabeçalhos de tabela
    oFonts["TITLE_MAIN"] := TFont():New("Arial", , -14, .T., .T.)
    oFonts["SUBTITLE"]   := TFont():New("Arial", , -10, .T., .T.)
    oFonts["SUB_UNDER"]  := TFont():New("Arial", , -10, .T., .T., , , , , .T.) // Negrito + Sublinhado
    oFonts["LABEL_BOLD"] := TFont():New("Arial", , -08, .T., .T.)
    oFonts["DATA_REG"]   := TFont():New("Arial", , -08, .T., .F.)
    oFonts["SMALL_BOLD"] := TFont():New("Arial", , -07, .T., .T.)
    oFonts["SMALL_REG"]  := TFont():New("Arial", , -07, .T., .F.)
    oFonts["FOOTER_CR"]  := TFont():New("Arial", , -08, .T., .T.)

    oBrushGray := TBrush():New(, RGB(225, 225, 225))

    While !(cAliasSC2)->(Eof())
        nPag := 1
        oPrinter:StartPage()

        // Imprime os Blocos Fixos do Topo (Blocos 1 a 5)
        nRow := PrtTopBlocks(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, nPag)

        // Imprime o Bloco 6: Matéria-Prima / Insumo a Utilizar (SD4 x SB1)
        nRow := PrtBlk6SD4(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, @nPag, nRow)

        // Imprime o Bloco 7: Roteiro Produtivo (SG2)
        nRow := PrtBlk7SG2(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, @nPag, nRow)

        // Imprime o Bloco 8: Rodapé Fixo na Base da Página e encerra a página da OP
        PrtBlk8Footer(oPrinter, oFonts, oBrushGray)
        oPrinter:EndPage()

        (cAliasSC2)->(DbSkip())
    EndDo

    (cAliasSC2)->(DbCloseArea())

    // Gera e exibe o PDF
    oPrinter:Preview()

    oBrushGray := Nil
    oFonts     := Nil
    oPrinter   := Nil
Return

/*/{Protheus.doc} GetLogoOP
Localiza o logotipo da empresa no StartPath (\system\) do servidor e copia para a pasta temporária
local do cliente (GetTempPath) via CpyS2T, pois o FWMSPrinter (IMP_PDF) processa a imagem no cliente.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@return character, Caminho local do logotipo acessível pelo FWMSPrinter
/*/
Static Function GetLogoOP()
    Local cGrpCompany := AllTrim(FWGrpCompany())
    Local cCodEmpGrp  := AllTrim(FWCodEmp())
    Local cUnitGrp    := AllTrim(FWUnitBusiness())
    Local cFilGrp     := AllTrim(FWFilial())
    Local cDescLogo   := ""
    Local cStart      := GetSrvProfString("Startpath", "")
    Local cTemp       := GetTempPath()
    Local cFonte      := ""
    Local cFileOnly   := ""
    Local cLogoLocal  := ""
    Local aLogos      := {}
    Local nI          := 0

    If !Empty(cStart) .And. !(Right(cStart, 1) $ "\/")
        cStart += "\"
    EndIf
    If !Empty(cTemp) .And. !(Right(cTemp, 1) $ "\/")
        cTemp += "\"
    EndIf

    If !Empty(cUnitGrp)
        cDescLogo := cGrpCompany + cCodEmpGrp + cUnitGrp + cFilGrp
    Else
        cDescLogo := cEmpAnt + cFilAnt
    EndIf

    // Lista de possíveis nomes de logotipo no diretório \system\ (StartPath)
    aAdd(aLogos, cStart + "lgmid.png")
    aAdd(aLogos, cStart + "LGMID.PNG")
    aAdd(aLogos, cStart + "LGMID01.PNG")
    aAdd(aLogos, cStart + "lgmid01.png")
    aAdd(aLogos, cStart + "LGRL" + cEmpAnt + cFilAnt + ".BMP")
    aAdd(aLogos, cStart + "lgrl" + cEmpAnt + cFilAnt + ".bmp")
    aAdd(aLogos, cStart + "LGRL" + cEmpAnt + ".BMP")
    aAdd(aLogos, cStart + "lgrl" + cEmpAnt + ".bmp")
    aAdd(aLogos, cStart + "LGRL01.BMP")
    aAdd(aLogos, cStart + "lgrl01.bmp")
    aAdd(aLogos, cStart + "DANFE" + cDescLogo + ".BMP")
    aAdd(aLogos, cStart + "DANFE" + cEmpAnt + ".BMP")
    aAdd(aLogos, "\system\lgmid.png")
    aAdd(aLogos, "\system\lgrl01.bmp")

    For nI := 1 To Len(aLogos)
        If File(aLogos[nI])
            cFonte := aLogos[nI]
            Exit
        EndIf
    Next nI

    If Empty(cFonte)
        Return ""
    EndIf

    // Copia a imagem do servidor (Linux) para a pasta temporária do cliente (Windows)
    CpyS2T(cFonte, cTemp, .T.)

    cFileOnly := SubStr(cFonte, RAt("\", StrTran(cFonte, "/", "\")) + 1)
    cLogoLocal := cTemp + cFileOnly

    If !File(cLogoLocal)
        Sleep(300)
    EndIf

    If File(cLogoLocal)
        Return cLogoLocal
    EndIf
Return cFonte

/*/{Protheus.doc} PrtTopBlocks
Coordena a impressão do cabeçalho e blocos superiores da OP (Blocos 1 a 5).
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param cAliasSC2, character, Alias aberto da query SC2
@param cLogo, character, Caminho do arquivo de logotipo
@param nPag, numeric, Número da página atual da OP
@return numeric, Coordenada vertical (nRow) após o Bloco 5
/*/
Static Function PrtTopBlocks(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, nPag)
    Local nRow      := 20
    Local aDadosSG2 := GetFirstSG2(cAliasSC2)

    // BLOCO 1: Cabeçalho Principal
    nRow := PrtBlk1Hdr(oPrinter, oFonts, cAliasSC2, cLogo, nPag, nRow)

    // BLOCO 2: Dados do Cliente, Pedido e Produto
    nRow := PrtBlk2Cli(oPrinter, oFonts, oBrushGray, cAliasSC2, nRow)

    // BLOCO 3: Parâmetros Técnicos de Injeção / Molde
    nRow := PrtBlk3Inj(oPrinter, oFonts, cAliasSC2, aDadosSG2, nRow)

    // BLOCO 4: Produção e Dimensões do Molde
    nRow := PrtBlk4Mol(oPrinter, oFonts, cAliasSC2, aDadosSG2, nRow)

    // BLOCO 5: Configuração e Setup
    nRow := PrtBlk5Set(oPrinter, oFonts, nRow)
Return nRow

/*/{Protheus.doc} CheckPageBreak
Verifica se a próxima impressão ultrapassará o limite antes do rodapé fixo (Bloco 8).
Caso positivo, imprime o rodapé fixo na página atual, abre nova página e reimprime o Bloco 1.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param cAliasSC2, character, Alias aberto da query SC2
@param cLogo, character, Caminho do logotipo
@param nPag, numeric, Número da página (passado por referência)
@param nRow, numeric, Linha vertical atual (passado por referência)
@param nNeedHeight, numeric, Altura necessária para o próximo bloco/linha
@return logical, .T. se houve quebra de página
/*/
Static Function CheckPageBreak(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, nPag, nRow, nNeedHeight)
    Local lBroke := .F.

    If (nRow + nNeedHeight) > LIMIT_FOOTER
        // Imprime o Bloco 8 (Rodapé Fixo) na base da página atual antes de quebrar
        PrtBlk8Footer(oPrinter, oFonts, oBrushGray)
        oPrinter:EndPage()

        // Inicia nova página e incrementa contador
        nPag++
        oPrinter:StartPage()
        nRow   := PrtBlk1Hdr(oPrinter, oFonts, cAliasSC2, cLogo, nPag, 20)
        lBroke := .T.
    EndIf
Return lBroke

/*/{Protheus.doc} PrtBlk1Hdr
Imprime o BLOCO 1: Cabeçalho Principal (Logo à esquerda, Título da OP ao centro, Página à direita).
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param cAliasSC2, character, Alias da SC2
@param cLogo, character, Caminho do logotipo
@param nPag, numeric, Número da página atual
@param nRow, numeric, Linha inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtBlk1Hdr(oPrinter, oFonts, cAliasSC2, cLogo, nPag, nRow)
    Local cNumOP  := AllTrim((cAliasSC2)->C2_NUM + (cAliasSC2)->C2_ITEM + (cAliasSC2)->C2_SEQUEN)
    Local cTitulo := "ORDEM DE PRODUÇÃO Nº: " + cNumOP
    Local cPagTxt := "Página: " + cValToChar(nPag)
    Local nHeight := 40

    // Moldura do Cabeçalho
    oPrinter:Box(nRow, MARGIN_LEFT, nRow + nHeight, MARGIN_RIGHT, "-4")

    // Canto superior esquerdo: Logotipo (copiado para o cliente via GetLogoOP)
    If !Empty(cLogo) .And. File(cLogo)
        oPrinter:SayBitmap(nRow + 4, MARGIN_LEFT + 6, cLogo, 85, 32)
    Else
        oPrinter:SayAlign(nRow + 12, MARGIN_LEFT + 6, "RewPlastic", oFonts["SUBTITLE"], 85, 15, , PAD_CENTER, 0)
    EndIf

    // Centro: Título em destaque
    oPrinter:SayAlign(nRow + 12, MARGIN_LEFT + 100, cTitulo, oFonts["TITLE_MAIN"], 370, 20, , PAD_CENTER, 0)

    // Canto superior direito: Número da Página
    oPrinter:SayAlign(nRow + 14, MARGIN_RIGHT - 90, cPagTxt, oFonts["LABEL_BOLD"], 82, 15, , PAD_RIGHT, 0)

Return (nRow + nHeight + 6)

/*/{Protheus.doc} PrtBlk2Cli
Imprime o BLOCO 2: Dados do Cliente, Pedido e Produto (com Tabela Interna de cabeçalho cinza claro).
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param cAliasSC2, character, Alias da SC2
@param nRow, numeric, Linha inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtBlk2Cli(oPrinter, oFonts, oBrushGray, cAliasSC2, nRow)
    Local cCliente  := ""
    Local cEmissao  := DtoC((cAliasSC2)->C2_EMISSAO)
    Local cPrazo    := DtoC((cAliasSC2)->C2_DATPRF)
    Local cPedido   := AllTrim((cAliasSC2)->C2_PEDIDO)
    Local cItemPV   := AllTrim((cAliasSC2)->C2_ITEMPV)
    Local cLote     := AllTrim((cAliasSC2)->C2_XLOTE)
    Local cCodProd  := AllTrim((cAliasSC2)->C2_PRODUTO)
    Local cCodCli   := AllTrim((cAliasSC2)->A7_CODCLI)
    Local cDescProd := AllTrim((cAliasSC2)->B1_DESC)
    Local cUnid     := AllTrim((cAliasSC2)->C2_UM)
    Local cQuant    := AllTrim(Transform((cAliasSC2)->C2_QUANT, PesqPict("SC2", "C2_QUANT")))
    Local nBoxTop   := nRow
    Local nBoxH     := 76
    Local nTblTop   := 0

    // Monta string do Cliente: Código + Loja + Nome Reduzido + Razão Social
    If !Empty((cAliasSC2)->C5_CLIENTE)
        cCliente := AllTrim((cAliasSC2)->C5_CLIENTE) + "/" + AllTrim((cAliasSC2)->C5_LOJACLI) + ;
                    " - " + AllTrim((cAliasSC2)->A1_NREDUZ) + " (" + AllTrim((cAliasSC2)->A1_NOME) + ")"
    Else
        cCliente := "PRODUÇÃO PARA ESTOQUE / SEM PEDIDO VINCULADO"
    EndIf

    If Empty(cLote)
        cLote := "______________"
    EndIf

    // Caixa externa do Bloco 2
    oPrinter:Box(nBoxTop, MARGIN_LEFT, nBoxTop + nBoxH, MARGIN_RIGHT, "-4")

    // Linha 1: Cliente e Data de Emissão
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 6,   "Cliente:",         oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 45,  cCliente,           oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 12, MARGIN_RIGHT - 135, "Data de Emissão:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_RIGHT - 60,  cEmissao,           oFonts["DATA_REG"])

    oPrinter:Line(nBoxTop + 18, MARGIN_LEFT, nBoxTop + 18, MARGIN_RIGHT)

    // Linha 2: Nº do Pedido | Item do Pedido | Nº do Lote
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 6,   "Nº do Pedido:",   oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 70,  cPedido,           oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 180, "Item do Pedido:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 250, cItemPV,           oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 350, "Nº do Lote:",     oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 405, cLote,             oFonts["DATA_REG"])

    // Tabela Interna de Produto (Cabeçalho com fundo cinza claro)
    nTblTop := nBoxTop + 36
    oPrinter:FillRect({nTblTop, MARGIN_LEFT + 1, nTblTop + 16, MARGIN_RIGHT - 1}, oBrushGray)
    oPrinter:Line(nTblTop,      MARGIN_LEFT, nTblTop,      MARGIN_RIGHT)
    oPrinter:Line(nTblTop + 16, MARGIN_LEFT, nTblTop + 16, MARGIN_RIGHT)

    // Divisórias verticais das colunas da tabela de produto
    // Colunas: Cód.ReW (20..95) | Código Cliente (95..180) | Descrição (180..410) | Qtde (410..480) | Un. (480..515) | Prazo (515..575)
    oPrinter:Line(nTblTop, 95,  nBoxTop + nBoxH, 95)
    oPrinter:Line(nTblTop, 180, nBoxTop + nBoxH, 180)
    oPrinter:Line(nTblTop, 410, nBoxTop + nBoxH, 410)
    oPrinter:Line(nTblTop, 480, nBoxTop + nBoxH, 480)
    oPrinter:Line(nTblTop, 515, nBoxTop + nBoxH, 515)

    // Títulos das colunas
    oPrinter:SayAlign(nTblTop + 3, MARGIN_LEFT + 2, "Cód.ReW",               oFonts["LABEL_BOLD"], 70,  12, , PAD_LEFT,   0)
    oPrinter:SayAlign(nTblTop + 3, 98,              "Código Cliente",        oFonts["LABEL_BOLD"], 80,  12, , PAD_LEFT,   0)
    oPrinter:SayAlign(nTblTop + 3, 183,             "Descrição do Produto",  oFonts["LABEL_BOLD"], 224, 12, , PAD_LEFT,   0)
    oPrinter:SayAlign(nTblTop + 3, 412,             "Qtde.",                 oFonts["LABEL_BOLD"], 65,  12, , PAD_RIGHT,  0)
    oPrinter:SayAlign(nTblTop + 3, 482,             "Un.",                   oFonts["LABEL_BOLD"], 30,  12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nTblTop + 3, 517,             "Prazo",                 oFonts["LABEL_BOLD"], 55,  12, , PAD_CENTER, 0)

    // Dados da linha do produto
    oPrinter:SayAlign(nTblTop + 21, MARGIN_LEFT + 2, cCodProd,  oFonts["DATA_REG"], 70,  14, , PAD_LEFT,   0)
    oPrinter:SayAlign(nTblTop + 21, 98,              cCodCli,   oFonts["DATA_REG"], 80,  14, , PAD_LEFT,   0)
    oPrinter:SayAlign(nTblTop + 21, 183,             cDescProd, oFonts["DATA_REG"], 224, 14, , PAD_LEFT,   0)
    oPrinter:SayAlign(nTblTop + 21, 412,             cQuant,    oFonts["DATA_REG"], 65,  14, , PAD_RIGHT,  0)
    oPrinter:SayAlign(nTblTop + 21, 482,             cUnid,     oFonts["DATA_REG"], 30,  14, , PAD_CENTER, 0)
    oPrinter:SayAlign(nTblTop + 21, 517,             cPrazo,    oFonts["DATA_REG"], 55,  14, , PAD_CENTER, 0)

Return (nBoxTop + nBoxH + 6)

/*/{Protheus.doc} PrtBlk3Inj
Imprime o BLOCO 3: Parâmetros Técnicos de Injeção / Molde utilizando B1_XCAVID e B1_XCICLO.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param cAliasSC2, character, Alias da SC2
@param aDadosSG2, array, Dados da primeira operação do roteiro SG2 {cRecurso, cDescRec, cFerram, nTempPad, nLotPad}
@param nRow, numeric, Linha inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtBlk3Inj(oPrinter, oFonts, cAliasSC2, aDadosSG2, nRow)
    Local nBoxTop     := nRow
    Local nBoxH       := 54
    Local nQuantOP    := (cAliasSC2)->C2_QUANT
    Local nQtdEmb     := (cAliasSC2)->B1_QE
    Local nPesoLiq    := (cAliasSC2)->B1_PESO
    Local nPesoBru    := (cAliasSC2)->B1_PESBRU
    Local nCavidades  := (cAliasSC2)->B1_XCAVID
    Local nCicloSeg   := (cAliasSC2)->B1_XCICLO
    Local nPecasHora  := 0
    Local nTempoTotal := 0
    Local nVolFechado := 0
    Local nQtdResid   := 0
    Local cCavTxt     := "____"
    Local cCicloTxt   := "____ s"
    Local cPecasHTxt  := "____"
    Local cTempoTxt   := "____ h"
    Local cVolTxt     := "0"
    Local cResidTxt   := "0"

    If nCavidades > 0
        cCavTxt := AllTrim(Transform(nCavidades, "@E 9,999"))
    EndIf

    If nCicloSeg > 0
        cCicloTxt := AllTrim(Transform(nCicloSeg, "@E 999.99")) + " s"
    EndIf

    // Cálculos automáticos de Peças/h e Tempo Total quando Cavidades e Ciclo estão preenchidos
    If nCavidades > 0 .And. nCicloSeg > 0
        nPecasHora := Round((3600 / nCicloSeg) * nCavidades, 2)
        cPecasHTxt := AllTrim(Transform(nPecasHora, "@E 999,999.99"))
        If nPecasHora > 0
            nTempoTotal := Round(nQuantOP / nPecasHora, 2)
            cTempoTxt   := AllTrim(Transform(nTempoTotal, "@E 999,999.99")) + " h"
        EndIf
    EndIf

    // Cálculo de Volumes Fechados e Quantidade Residual com base em B1_QE (Quantidade por Embalagem)
    If nQtdEmb > 0
        nVolFechado := Int(nQuantOP / nQtdEmb)
        nQtdResid   := nQuantOP - (nVolFechado * nQtdEmb)
    EndIf
    cVolTxt   := cValToChar(nVolFechado)
    cResidTxt := AllTrim(Transform(nQtdResid, PesqPict("SC2", "C2_QUANT")))

    // Caixa externa e linhas divisórias horizontais do Bloco 3
    oPrinter:Box(nBoxTop, MARGIN_LEFT, nBoxTop + nBoxH, MARGIN_RIGHT, "-4")
    oPrinter:Line(nBoxTop + 18, MARGIN_LEFT, nBoxTop + 18, MARGIN_RIGHT)
    oPrinter:Line(nBoxTop + 36, MARGIN_LEFT, nBoxTop + 36, MARGIN_RIGHT)

    // Linha 1: Nº Cavidades | Ciclo em Segundos | Peças/h | Tempo Total
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 6,   "Nº Cavidades:",      oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 72,  cCavTxt,              oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 145, "Ciclo em Segundos:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 235, cCicloTxt,            oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 310, "Peças/h:",           oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 355, cPecasHTxt,           oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 430, "Tempo Total:",       oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 490, cTempoTxt,            oFonts["DATA_REG"])

    // Linha 2: Quantidade por Volume | Volumes Fechados | Quantidade Residual
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 6,   "Quantidade por Volume:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 115, AllTrim(Transform(nQtdEmb, PesqPict("SB1", "B1_QE"))), oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 200, "Volumes Fechados:",      oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 290, cVolTxt,                  oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 370, "Quantidade Residual:",   oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 470, cResidTxt,                oFonts["DATA_REG"])

    // Linha 3: Peso Líquido | Peso Bruto
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 6,   "Peso Líquido:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 72,  AllTrim(Transform(nPesoLiq, PesqPict("SB1", "B1_PESO"))),   oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 200, "Peso Bruto:",   oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 260, AllTrim(Transform(nPesoBru, PesqPict("SB1", "B1_PESBRU"))), oFonts["DATA_REG"])

Return (nBoxTop + nBoxH + 6)

/*/{Protheus.doc} PrtBlk4Mol
Imprime o BLOCO 4: Produção e Dimensões do Molde utilizando B1_XMOLDE, B1_XALTMOL, B1_XLARMOL, B1_XCOMMOL e B1_XCICLO.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param cAliasSC2, character, Alias da SC2
@param aDadosSG2, array, Dados da primeira operação do roteiro SG2 {cRecurso, cDescRec, cFerram, nTempPad, nLotPad}
@param nRow, numeric, Linha inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtBlk4Mol(oPrinter, oFonts, cAliasSC2, aDadosSG2, nRow)
    Local nBoxTop    := nRow
    Local nBoxH      := 54
    Local cMolde     := AllTrim((cAliasSC2)->B1_XMOLDE)
    Local cMaquina   := ""
    Local cAltMolde  := "______"
    Local cLarMolde  := "______"
    Local cComMolde  := "______"
    Local cCicloEst  := "______"

    // Se B1_XMOLDE estiver em branco, faz fallback para a ferramenta do roteiro (SG2->G2_FERRAM)
    If Empty(cMolde)
        cMolde := aDadosSG2[3]
    EndIf
    If Empty(cMolde)
        cMolde := "________________"
    EndIf

    // Dimensões do Molde na SB1 (B1_XALTMOL, B1_XLARMOL, B1_XCOMMOL)
    If (cAliasSC2)->B1_XALTMOL > 0
        cAltMolde := AllTrim(Transform((cAliasSC2)->B1_XALTMOL, "@E 9,999.99"))
    EndIf
    If (cAliasSC2)->B1_XLARMOL > 0
        cLarMolde := AllTrim(Transform((cAliasSC2)->B1_XLARMOL, "@E 9,999.99"))
    EndIf
    If (cAliasSC2)->B1_XCOMMOL > 0
        cComMolde := AllTrim(Transform((cAliasSC2)->B1_XCOMMOL, "@E 9,999.99"))
    EndIf

    // Máquina sugerida (SG2->G2_RECURSO + SH1->H1_DESCRI)
    If !Empty(aDadosSG2[1])
        cMaquina := AllTrim(aDadosSG2[1]) + " - " + AllTrim(aDadosSG2[2])
    Else
        cMaquina := "____________________________"
    EndIf

    // Ciclo estimado: prioriza B1_XCICLO (em segundos), com fallback para G2_TEMPAD do roteiro
    If (cAliasSC2)->B1_XCICLO > 0
        cCicloEst := AllTrim(Transform((cAliasSC2)->B1_XCICLO, "@E 999.99")) + " s"
    ElseIf aDadosSG2[4] > 0
        cCicloEst := AllTrim(Transform(aDadosSG2[4], "@E 999.99")) + " h (Padrão Roteiro)"
    EndIf

    // Caixa externa e linhas divisórias horizontais do Bloco 4
    oPrinter:Box(nBoxTop, MARGIN_LEFT, nBoxTop + nBoxH, MARGIN_RIGHT, "-4")
    oPrinter:Line(nBoxTop + 18, MARGIN_LEFT, nBoxTop + 18, MARGIN_RIGHT)
    oPrinter:Line(nBoxTop + 36, MARGIN_LEFT, nBoxTop + 36, MARGIN_RIGHT)

    // Linha 1: Produção iniciada em | Nº do Molde
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 6,   "Produção iniciada em:  ____/____/____  às  ____:____ h", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 320, "Nº do Molde:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 12, MARGIN_LEFT + 385, cMolde,         oFonts["DATA_REG"])

    // Linha 2: Dimensões do Molde (mm)
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 6,   "Dimensões do Molde (mm):", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 140, "Altura: " + cAltMolde + "     Largura: " + cLarMolde + "     Comprimento: " + cComMolde, oFonts["DATA_REG"])

    // Linha 3: Máquina sugerida | Ciclo estimado
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 6,   "Máquina sugerida:", oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 95,  cMaquina,            oFonts["DATA_REG"])
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 350, "Ciclo estimado:",   oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 48, MARGIN_LEFT + 425, cCicloEst,           oFonts["DATA_REG"])

Return (nBoxTop + nBoxH + 6)

/*/{Protheus.doc} PrtBlk5Set
Imprime o BLOCO 5: Configuração e Setup.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param nRow, numeric, Linha inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtBlk5Set(oPrinter, oFonts, nRow)
    Local nBoxTop := nRow
    Local nBoxH   := 52

    oPrinter:Box(nBoxTop, MARGIN_LEFT, nBoxTop + nBoxH, MARGIN_RIGHT, "-4")

    // Título centralizado sublinhado
    oPrinter:SayAlign(nBoxTop + 3, MARGIN_LEFT, "Configuração e Setup", oFonts["SUB_UNDER"], MARGIN_RIGHT - MARGIN_LEFT, 14, , PAD_CENTER, 0)
    oPrinter:Line(nBoxTop + 18, MARGIN_LEFT, nBoxTop + 18, MARGIN_RIGHT)

    // Linha 1: Início e Término
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 6,   "Início:  ____/____/____  às  ____:____ h",  oFonts["LABEL_BOLD"])
    oPrinter:Say(nBoxTop + 30, MARGIN_LEFT + 280, "Término:  ____/____/____  às  ____:____ h", oFonts["LABEL_BOLD"])
    oPrinter:Line(nBoxTop + 35, MARGIN_LEFT, nBoxTop + 35, MARGIN_RIGHT)

    // Linha 2: Responsável
    oPrinter:Say(nBoxTop + 47, MARGIN_LEFT + 6, "Responsável: _________________________________________________________________________", oFonts["LABEL_BOLD"])

Return (nBoxTop + nBoxH + 8)

/*/{Protheus.doc} PrtBlk6SD4
Imprime o BLOCO 6: Matéria-Prima / Insumo a Utilizar (Grid com cabeçalho cinza buscando da SD4 x SB1).
Calcula o (%) de Uso proporcional ao total empenhado e controla quebra de página.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param cAliasSC2, character, Alias da SC2
@param cLogo, character, Caminho do logotipo
@param nPag, numeric, Número da página atual (por referência)
@param nRow, numeric, Linha vertical atual
@return numeric, Próxima linha disponível (nRow)
@table SD4, SB1
/*/
Static Function PrtBlk6SD4(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, nPag, nRow)
    Local cAliasSD4 := GetNextAlias()
    Local cOpFull   := PadR((cAliasSC2)->C2_NUM + (cAliasSC2)->C2_ITEM + (cAliasSC2)->C2_SEQUEN + (cAliasSC2)->C2_ITEMGRD, TamSX3("D4_OP")[1])
    Local aItensSD4 := {}
    Local nTotQtde  := 0
    Local nIdx      := 0
    Local nPercUso  := 0
    Local nRowH     := 16
    Local cLoteMP   := ""

    // Consulta empenhos da OP na SD4 cruzando com SB1 via BeginSql
    BeginSql Alias cAliasSD4
        SELECT
            SD4.D4_COD,
            SD4.D4_QTDEORI,
            SD4.D4_LOTECTL,
            SB1.B1_DESC,
            SB1.B1_UM
        FROM %table:SD4% SD4
        INNER JOIN %table:SB1% SB1
            ON  SB1.B1_FILIAL = %xFilial:SB1%
            AND SB1.B1_COD    = SD4.D4_COD
            AND SB1.%notDel%
        WHERE SD4.D4_FILIAL = %xFilial:SD4%
          AND SD4.D4_OP     = %Exp:cOpFull%
          AND SD4.%notDel%
        ORDER BY SD4.D4_COD
    EndSql

    While !(cAliasSD4)->(Eof())
        aAdd(aItensSD4, { ;
            AllTrim((cAliasSD4)->D4_COD), ;
            AllTrim((cAliasSD4)->B1_DESC), ;
            AllTrim((cAliasSD4)->B1_UM), ;
            (cAliasSD4)->D4_QTDEORI, ;
            AllTrim((cAliasSD4)->D4_LOTECTL) ;
        })
        nTotQtde += (cAliasSD4)->D4_QTDEORI
        (cAliasSD4)->(DbSkip())
    EndDo
    (cAliasSD4)->(DbCloseArea())

    // Verifica espaço para o cabeçalho do Bloco 6 + pelo menos 1 linha
    CheckPageBreak(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, @nPag, @nRow, 36)

    // Imprime Cabeçalho do Grid de Matéria-Prima
    nRow := PrtHdrSD4(oPrinter, oFonts, oBrushGray, nRow)

    If Len(aItensSD4) == 0
        oPrinter:Box(nRow, MARGIN_LEFT, nRow + nRowH, MARGIN_RIGHT, "-4")
        oPrinter:SayAlign(nRow + 3, MARGIN_LEFT + 4, "Nenhum empenho (SD4) encontrado para esta Ordem de Produção.", oFonts["SMALL_REG"], 540, 12, , PAD_LEFT, 0)
        nRow += nRowH
    Else
        For nIdx := 1 To Len(aItensSD4)
            // Verifica quebra de página antes de imprimir cada linha do empenho
            If CheckPageBreak(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, @nPag, @nRow, nRowH)
                nRow := PrtHdrSD4(oPrinter, oFonts, oBrushGray, nRow)
            EndIf

            // Calcula (%) de Uso proporcional ao peso/quantidade total empenhada
            If nTotQtde > 0
                nPercUso := Round((aItensSD4[nIdx][4] / nTotQtde) * 100, 2)
            Else
                nPercUso := 0
            EndIf

            cLoteMP := aItensSD4[nIdx][5]

            // Desenha linha e divisórias verticais
            // Colunas: Código(20..85) | Descrição(85..245) | Un.(245..270) | Qtde(270..330) | (%) Uso(330..375) | Nº Lote(375..435) | Fornecedor(435..520) | Data(520..575)
            oPrinter:Box(nRow, MARGIN_LEFT, nRow + nRowH, MARGIN_RIGHT, "-4")
            oPrinter:Line(nRow, 85,  nRow + nRowH, 85)
            oPrinter:Line(nRow, 245, nRow + nRowH, 245)
            oPrinter:Line(nRow, 270, nRow + nRowH, 270)
            oPrinter:Line(nRow, 330, nRow + nRowH, 330)
            oPrinter:Line(nRow, 375, nRow + nRowH, 375)
            oPrinter:Line(nRow, 435, nRow + nRowH, 435)
            oPrinter:Line(nRow, 520, nRow + nRowH, 520)

            oPrinter:SayAlign(nRow + 3, MARGIN_LEFT + 2, aItensSD4[nIdx][1], oFonts["SMALL_REG"], 62,  12, , PAD_LEFT,   0)
            oPrinter:SayAlign(nRow + 3, 87,              aItensSD4[nIdx][2], oFonts["SMALL_REG"], 155, 12, , PAD_LEFT,   0)
            oPrinter:SayAlign(nRow + 3, 247,             aItensSD4[nIdx][3], oFonts["SMALL_REG"], 20,  12, , PAD_CENTER, 0)
            oPrinter:SayAlign(nRow + 3, 272,             AllTrim(Transform(aItensSD4[nIdx][4], PesqPict("SD4", "D4_QTDEORI"))), oFonts["SMALL_REG"], 55, 12, , PAD_RIGHT, 0)
            oPrinter:SayAlign(nRow + 3, 332,             AllTrim(Transform(nPercUso, "@E 999.99")) + "%", oFonts["SMALL_REG"], 40, 12, , PAD_RIGHT, 0)
            oPrinter:SayAlign(nRow + 3, 377,             cLoteMP,            oFonts["SMALL_REG"], 55,  12, , PAD_LEFT,   0)
            // Colunas Fornecedor (435..520) e Data (520..575) ficam em branco para apontamento manual

            nRow += nRowH
        Next nIdx
    EndIf

Return (nRow + 8)

/*/{Protheus.doc} PrtHdrSD4
Imprime o título e o cabeçalho de colunas com fundo cinza do Bloco 6 (Matéria-Prima / Insumo).
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param nRow, numeric, Linha vertical inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtHdrSD4(oPrinter, oFonts, oBrushGray, nRow)
    Local nHdrH := 16

    // Faixa de título da seção
    oPrinter:FillRect({nRow, MARGIN_LEFT, nRow + nHdrH, MARGIN_RIGHT}, oBrushGray)
    oPrinter:Box(nRow, MARGIN_LEFT, nRow + nHdrH, MARGIN_RIGHT, "-4")
    oPrinter:SayAlign(nRow + 2, MARGIN_LEFT, "MATÉRIA-PRIMA / INSUMO A UTILIZAR", oFonts["LABEL_BOLD"], MARGIN_RIGHT - MARGIN_LEFT, 12, , PAD_CENTER, 0)
    nRow += nHdrH

    // Cabeçalho das colunas
    oPrinter:FillRect({nRow, MARGIN_LEFT, nRow + nHdrH, MARGIN_RIGHT}, oBrushGray)
    oPrinter:Box(nRow, MARGIN_LEFT, nRow + nHdrH, MARGIN_RIGHT, "-4")
    oPrinter:Line(nRow, 85,  nRow + nHdrH, 85)
    oPrinter:Line(nRow, 245, nRow + nHdrH, 245)
    oPrinter:Line(nRow, 270, nRow + nHdrH, 270)
    oPrinter:Line(nRow, 330, nRow + nHdrH, 330)
    oPrinter:Line(nRow, 375, nRow + nHdrH, 375)
    oPrinter:Line(nRow, 435, nRow + nHdrH, 435)
    oPrinter:Line(nRow, 520, nRow + nHdrH, 520)

    oPrinter:SayAlign(nRow + 3, MARGIN_LEFT + 2, "Código",                  oFonts["SMALL_BOLD"], 62,  12, , PAD_LEFT,   0)
    oPrinter:SayAlign(nRow + 3, 87,              "Descrição da MP / Insumo", oFonts["SMALL_BOLD"], 155, 12, , PAD_LEFT,   0)
    oPrinter:SayAlign(nRow + 3, 247,             "Un.",                     oFonts["SMALL_BOLD"], 20,  12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nRow + 3, 272,             "Qtde",                    oFonts["SMALL_BOLD"], 55,  12, , PAD_RIGHT,  0)
    oPrinter:SayAlign(nRow + 3, 332,             "(%) Uso",                 oFonts["SMALL_BOLD"], 40,  12, , PAD_RIGHT,  0)
    oPrinter:SayAlign(nRow + 3, 377,             "Nº Lote",                 oFonts["SMALL_BOLD"], 55,  12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nRow + 3, 437,             "Fornecedor",              oFonts["SMALL_BOLD"], 80,  12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nRow + 3, 522,             "Data",                    oFonts["SMALL_BOLD"], 50,  12, , PAD_CENTER, 0)

Return (nRow + nHdrH)

/*/{Protheus.doc} PrtBlk7SG2
Imprime o BLOCO 7: Roteiro Produtivo (Grid com cabeçalho cinza buscando operações na SG2).
Trata quebra de página antes do rodapé fixo.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param cAliasSC2, character, Alias da SC2
@param cLogo, character, Caminho do logotipo
@param nPag, numeric, Número da página atual (por referência)
@param nRow, numeric, Linha vertical atual
@return numeric, Próxima linha disponível (nRow)
@table SG2
/*/
Static Function PrtBlk7SG2(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, nPag, nRow)
    Local cAliasSG2 := GetNextAlias()
    Local cProduto  := (cAliasSC2)->C2_PRODUTO
    Local cRoteiro  := (cAliasSC2)->C2_ROTEIRO
    Local nBlockH   := 32
    Local cLinApont := ""
    Local lHasOper  := .F.

    If Empty(cRoteiro)
        cRoteiro := "01"
    EndIf

    // Verifica espaço para o cabeçalho do Roteiro + ao menos 1 operação
    CheckPageBreak(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, @nPag, @nRow, 16 + nBlockH)

    // Imprime cabeçalho cinza do Bloco 7
    nRow := PrtHdrSG2(oPrinter, oFonts, oBrushGray, nRow)

    BeginSql Alias cAliasSG2
        SELECT
            SG2.G2_OPERAC,
            SG2.G2_DESCRI
        FROM %table:SG2% SG2
        WHERE SG2.G2_FILIAL  = %xFilial:SG2%
          AND SG2.G2_PRODUTO = %Exp:cProduto%
          AND SG2.G2_CODIGO  = %Exp:cRoteiro%
          AND SG2.%notDel%
        ORDER BY SG2.G2_OPERAC
    EndSql

    cLinApont := "Func: ____________   ___/___/___   Hr. Início: ______   Hr. Fim: ______   Qtd Aprov.: ________   Qtd Reprov.: ________   Visto: __________"

    While !(cAliasSG2)->(Eof())
        lHasOper := .T.

        // Verifica quebra de página para o bloco de 2 linhas da operação
        If CheckPageBreak(oPrinter, oFonts, oBrushGray, cAliasSC2, cLogo, @nPag, @nRow, nBlockH)
            nRow := PrtHdrSG2(oPrinter, oFonts, oBrushGray, nRow)
        EndIf

        oPrinter:Box(nRow, MARGIN_LEFT, nRow + nBlockH, MARGIN_RIGHT, "-4")

        // Linha 1: Código da Operação + Descrição
        oPrinter:Say(nRow + 11, MARGIN_LEFT + 6, ;
            "Operação: " + AllTrim((cAliasSG2)->G2_OPERAC) + " - " + AllTrim((cAliasSG2)->G2_DESCRI), ;
            oFonts["LABEL_BOLD"])

        // Linha 2: Campos para apontamento manual no chão de fábrica
        oPrinter:Say(nRow + 26, MARGIN_LEFT + 6, cLinApont, oFonts["SMALL_REG"])

        nRow += nBlockH
        (cAliasSG2)->(DbSkip())
    EndDo

    (cAliasSG2)->(DbCloseArea())

    If !lHasOper
        oPrinter:Box(nRow, MARGIN_LEFT, nRow + 18, MARGIN_RIGHT, "-4")
        oPrinter:SayAlign(nRow + 3, MARGIN_LEFT + 4, "Nenhuma operação cadastrada no roteiro (" + AllTrim(cRoteiro) + ") para este produto.", oFonts["SMALL_REG"], 540, 12, , PAD_LEFT, 0)
        nRow += 18
    EndIf

Return (nRow + 6)

/*/{Protheus.doc} PrtHdrSG2
Imprime a faixa de cabeçalho cinza do Bloco 7 (Roteiro Produtivo).
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@param nRow, numeric, Linha vertical inicial
@return numeric, Próxima linha disponível (nRow)
/*/
Static Function PrtHdrSG2(oPrinter, oFonts, oBrushGray, nRow)
    Local nHdrH := 16

    oPrinter:FillRect({nRow, MARGIN_LEFT, nRow + nHdrH, MARGIN_RIGHT}, oBrushGray)
    oPrinter:Box(nRow, MARGIN_LEFT, nRow + nHdrH, MARGIN_RIGHT, "-4")
    oPrinter:SayAlign(nRow + 2, MARGIN_LEFT, "ROTEIRO PRODUTIVO", oFonts["LABEL_BOLD"], MARGIN_RIGHT - MARGIN_LEFT, 12, , PAD_CENTER, 0)

Return (nRow + nHdrH)

/*/{Protheus.doc} PrtBlk8Footer
Imprime o BLOCO 8: Rodapé Fixo na Base da Página.
Duas tabelas lado a lado ("Lotes MP Resinas" e "Lotes MP Masters") + "© RewPlastic" centralizado.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param oPrinter, object, Instância do FWMSPrinter
@param oFonts, json, Dicionário de fontes TFont
@param oBrushGray, object, Pincel TBrush cinza claro
@return nil, Sem retorno
/*/
Static Function PrtBlk8Footer(oPrinter, oFonts, oBrushGray)
    Local nFootTop := 715
    Local nRowH    := 15
    Local nLeftL   := MARGIN_LEFT
    Local nLeftR   := 290
    Local nRightL  := 305
    Local nRightR  := MARGIN_RIGHT

    // =========================================================================
    // TABELA ESQUERDA: Lotes MP Resinas (Colunas: 20..290)
    // =========================================================================
    // Título
    oPrinter:FillRect({nFootTop, nLeftL, nFootTop + nRowH, nLeftR}, oBrushGray)
    oPrinter:Box(nFootTop, nLeftL, nFootTop + nRowH, nLeftR, "-4")
    oPrinter:SayAlign(nFootTop + 2, nLeftL, "Lotes MP Resinas", oFonts["LABEL_BOLD"], nLeftR - nLeftL, 12, , PAD_CENTER, 0)

    // Subcolunas: Fornecedor (20..145) | Nº Lote (145..235) | Data (235..290)
    oPrinter:FillRect({nFootTop + nRowH, nLeftL, nFootTop + (nRowH * 2), nLeftR}, oBrushGray)
    oPrinter:Box(nFootTop + nRowH, nLeftL, nFootTop + (nRowH * 2), nLeftR, "-4")
    oPrinter:SayAlign(nFootTop + nRowH + 2, nLeftL + 2, "Fornecedor", oFonts["SMALL_BOLD"], 120, 12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nFootTop + nRowH + 2, 147,        "Nº Lote",    oFonts["SMALL_BOLD"], 86,  12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nFootTop + nRowH + 2, 237,        "Data",       oFonts["SMALL_BOLD"], 50,  12, , PAD_CENTER, 0)

    // 2 Linhas em branco para preenchimento manual
    oPrinter:Box(nFootTop + (nRowH * 2), nLeftL, nFootTop + (nRowH * 3), nLeftR, "-4")
    oPrinter:Box(nFootTop + (nRowH * 3), nLeftL, nFootTop + (nRowH * 4), nLeftR, "-4")
    oPrinter:Line(nFootTop + nRowH, 145, nFootTop + (nRowH * 4), 145)
    oPrinter:Line(nFootTop + nRowH, 235, nFootTop + (nRowH * 4), 235)

    // =========================================================================
    // TABELA DIREITA: Lotes MP Masters (Colunas: 305..575)
    // =========================================================================
    // Título
    oPrinter:FillRect({nFootTop, nRightL, nFootTop + nRowH, nRightR}, oBrushGray)
    oPrinter:Box(nFootTop, nRightL, nFootTop + nRowH, nRightR, "-4")
    oPrinter:SayAlign(nFootTop + 2, nRightL, "Lotes MP Masters", oFonts["LABEL_BOLD"], nRightR - nRightL, 12, , PAD_CENTER, 0)

    // Subcolunas: Fornecedor (305..430) | Nº Lote (430..520) | Data (520..575)
    oPrinter:FillRect({nFootTop + nRowH, nRightL, nFootTop + (nRowH * 2), nRightR}, oBrushGray)
    oPrinter:Box(nFootTop + nRowH, nRightL, nFootTop + (nRowH * 2), nRightR, "-4")
    oPrinter:SayAlign(nFootTop + nRowH + 2, nRightL + 2, "Fornecedor", oFonts["SMALL_BOLD"], 120, 12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nFootTop + nRowH + 2, 432,         "Nº Lote",    oFonts["SMALL_BOLD"], 86,  12, , PAD_CENTER, 0)
    oPrinter:SayAlign(nFootTop + nRowH + 2, 522,         "Data",       oFonts["SMALL_BOLD"], 50,  12, , PAD_CENTER, 0)

    // 2 Linhas em branco para preenchimento manual
    oPrinter:Box(nFootTop + (nRowH * 2), nRightL, nFootTop + (nRowH * 3), nRightR, "-4")
    oPrinter:Box(nFootTop + (nRowH * 3), nRightL, nFootTop + (nRowH * 4), nRightR, "-4")
    oPrinter:Line(nFootTop + nRowH, 430, nFootTop + (nRowH * 4), 430)
    oPrinter:Line(nFootTop + nRowH, 520, nFootTop + (nRowH * 4), 520)

    // Abaixo das tabelas, centralizado: © RewPlastic
    oPrinter:SayAlign(nFootTop + (nRowH * 4) + 6, MARGIN_LEFT, "© RewPlastic", oFonts["FOOTER_CR"], MARGIN_RIGHT - MARGIN_LEFT, 14, , PAD_CENTER, 0)
Return

/*/{Protheus.doc} GetFirstSG2
Busca os dados da primeira operação do roteiro produtivo (SG2) cruzando com Recursos (SH1)
para abastecer as informações de Máquina Sugerida, Ferramenta/Molde e Ciclo Estimado nos Blocos 3 e 4.
@type static function
@author Arquiteto Protheus
@since 23/11/2026
@param cAliasSC2, character, Alias aberto da query principal SC2
@return array, {cRecurso, cDescRecurso, cFerramenta, nTempoPadrao, nLotePadrao}
@table SG2, SH1
/*/
Static Function GetFirstSG2(cAliasSC2)
    Local aRet      := {"", "", "", 0, 0}
    Local cAliasTmp := GetNextAlias()
    Local cProduto  := (cAliasSC2)->C2_PRODUTO
    Local cRoteiro  := (cAliasSC2)->C2_ROTEIRO

    If Empty(cRoteiro)
        cRoteiro := "01"
    EndIf

    BeginSql Alias cAliasTmp
        SELECT
            SG2.G2_RECURSO,
            SG2.G2_FERRAM,
            SG2.G2_TEMPAD,
            SG2.G2_LOTEPAD,
            COALESCE(SH1.H1_DESCRI, ' ') AS H1_DESCRI
        FROM %table:SG2% SG2
        LEFT JOIN %table:SH1% SH1
            ON  SH1.H1_FILIAL = %xFilial:SH1%
            AND SH1.H1_CODIGO = SG2.G2_RECURSO
            AND SH1.%notDel%
        WHERE SG2.G2_FILIAL  = %xFilial:SG2%
          AND SG2.G2_PRODUTO = %Exp:cProduto%
          AND SG2.G2_CODIGO  = %Exp:cRoteiro%
          AND SG2.%notDel%
        ORDER BY SG2.G2_OPERAC
    EndSql

    If !(cAliasTmp)->(Eof())
        aRet[1] := AllTrim((cAliasTmp)->G2_RECURSO)
        aRet[2] := AllTrim((cAliasTmp)->H1_DESCRI)
        aRet[3] := AllTrim((cAliasTmp)->G2_FERRAM)
        aRet[4] := (cAliasTmp)->G2_TEMPAD
        aRet[5] := (cAliasTmp)->G2_LOTEPAD
    EndIf

    (cAliasTmp)->(DbCloseArea())
Return aRet
