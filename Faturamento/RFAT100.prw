#include "totvs.ch"

/*/{Protheus.doc} RFAT100
    Impressao Grafica e Exportacao em HTML do Orcamento de Venda
    Gera arquivo HTML salvo no diretorio %temp% do usuario
    e abre automaticamente no navegador padrao com suporte a impressao (PDF/Papel).
    @type    User Function
    @author  Protheus / Totvs
    @since   17/09/2026
    @version 3.2
    @obs     Somente IPI mantido. Logo 100% independente da maquina do usuario (leitura binaria + Base64 embutido no fonte) e layout otimizado para quebra de pagina (A4 Retrato/Paisagem).
/*/
User Function RFAT100()

    Local cPerg        := "RFAT100"
    Local nItemSeq     := 0
    Local cHtml        := ""
    Local cPathTemp    := GetTempPath()
    Local cNomeArq     := ""
    Local cArquivo     := ""
    Local nHandle      := 0
    Local nOrientacao  := 1 // 1=Retrato, 2=Paisagem

    // Flags de campos customizados (cacheados fora de loop - CA1003)
    Local lEmail       := .F.
    Local lxVend1      := SCJ->(FieldPos("CJ_XVEND1")) > 0
    Local lVend1       := SCJ->(FieldPos("CJ_VEND1")) > 0
    Local lVend        := SCJ->(FieldPos("CJ_VEND")) > 0
    Local lxTrans      := SCJ->(FieldPos("CJ_XTRANSP")) > 0
    Local lTransp      := SCJ->(FieldPos("CJ_TRANSP")) > 0
    Local lxFrete      := SCJ->(FieldPos("CJ_XFRETE")) > 0
    Local lTpFrete     := SCJ->(FieldPos("CJ_TPFRETE")) > 0
    Local lxOBS        := SCJ->(FieldPos("CJ_XOBS")) > 0
    Local lCkUm        := SCK->(FieldPos("CK_UM")) > 0
    Local lCkObs       := SCK->(FieldPos("CK_OBS")) > 0

    // Impostos e totais
    Local lIpi         := .F.
    Local nIpi         := 0
    Local nVlrIpi      := 0
    Local nTotalItem   := 0
    Local nTotProd     := 0
    Local nTotIpi      := 0
    Local nTotFrete    := 0
    Local nTotGer      := 0

    // Dados da empresa
    Local cEmpNome     := ""
    Local cEmpCnpj     := ""
    Local cEmpInsc     := ""
    Local cEmpTel      := ""
    Local cEmpFax      := ""
    Local cEmpEnd      := ""
    Local cEmpCid      := ""
    Local cEmpLogra    := ""
    Local cEmpBairro   := ""
    Local cEmpMun      := ""
    Local cEmpUf       := ""
    Local cEmpCep      := ""

    // Dados do cliente
    Local aEnd         := {}
    Local cRazao       := ""
    Local cEnd         := ""
    Local cNr          := ""
    Local cEndComp     := ""
    Local cBairro      := ""
    Local cCidade      := ""
    Local cEstado      := ""
    Local cCep         := ""
    Local cCNPJ        := ""
    Local cIE          := ""
    Local cContato     := ""
    Local cTelCli      := ""
    Local cEmailCli    := ""

    // Dados comerciais
    Local cVendedor    := ""
    Local cTransp      := ""
    Local cCondPag     := ""
    Local cTipoFre     := ""
    Local cNumLacre    := "SEQUENCIAL"
    Local cObsGeral    := ""

    // Logotipo
    Local cLogoSrc     := ""

    // Mascaras
    Local cPicVal      := PesqPict("SCK", "CK_VALOR")
    Local cPicPrc      := PesqPict("SCK", "CK_PRCVEN")
    Local cPicQtd      := PesqPict("SCK", "CK_QTDVEN")
    Local cPicIpi      := PesqPict("SB1", "B1_IPI")
    Local cPicFre      := PesqPict("SCJ", "CJ_FRETE")

    // Itens e controle de orientacao
    Local cLinhasItens := ""
    Local cDescProd    := ""
    Local cUM          := ""
    Local cOrientCss   := "portrait"
    Local cPageMode    := "portrait-mode"
    Local cBtnPortAct  := "active"
    Local cBtnLandAct  := ""
    Local cTelHeader   := ""

    // ---------------------------------------------------------------------
    // Fallbacks de mascaras
    // ---------------------------------------------------------------------
    If Empty(cPicVal)
        cPicVal := "@E 999,999,999.99"
    EndIf
    If Empty(cPicPrc)
        cPicPrc := "@E 999,999.9999"
    EndIf
    If Empty(cPicQtd)
        cPicQtd := "@E 999,999.99"
    EndIf
    If Empty(cPicIpi)
        cPicIpi := "@E 99.99"
    EndIf
    If Empty(cPicFre)
        cPicFre := "@E 999,999.99"
    EndIf

    // ---------------------------------------------------------------------
    // Se a SCJ nao estiver posicionada (chamada via menu), solicita o orcamento
    // ---------------------------------------------------------------------
    If SCJ->(EoF()) .Or. Empty(SCJ->CJ_NUM)
        If !Pergunte(cPerg, .T.)
            Return Nil
        EndIf
        SCJ->(DbSetOrder(1))
        If !SCJ->(DbSeek(xFilial("SCJ") + mv_par01))
            MsgStop("Orcamento de venda nao localizado!", "Atencao")
            Return Nil
        EndIf
        If Type("mv_par02") == "N" .And. mv_par02 == 2
            nOrientacao := 2
        EndIf
    EndIf

    If nOrientacao == 2
        cOrientCss  := "landscape"
        cPageMode   := "landscape-mode"
        cBtnPortAct := ""
        cBtnLandAct := "active"
    EndIf

    cNomeArq := "Orcamento_" + AllTrim(SCJ->CJ_NUM) + "_" + StrTran(Time(), ":", "") + ".html"
    cArquivo := cPathTemp + cNomeArq

    SCK->(DbSetOrder(1))
    If !SCK->(DbSeek(xFilial("SCK") + SCJ->CJ_NUM))
        MsgStop("Nao ha itens cadastrados para este orcamento!", "Atencao")
        Return Nil
    EndIf

    // ---------------------------------------------------------------------
    // Dados da empresa (SM0)
    // ---------------------------------------------------------------------
    If !Empty(SM0->M0_NOMECOM)
        cEmpNome := AllTrim(SM0->M0_NOMECOM)
    Else
        cEmpNome := AllTrim(SM0->M0_NOME)
    EndIf
    cEmpCnpj := AllTrim(Transform(SM0->M0_CGC, "@r 99.999.999/9999-99"))
    cEmpInsc := AllTrim(SM0->M0_INSC)
    cEmpTel  := AllTrim(Transform(SM0->M0_TEL, "@r (99) 9999-9999"))

    // Fax (somente se contiver numeros)
    If !Empty(SM0->M0_FAX) .And. !Empty(StrTran(StrTran(StrTran(AllTrim(SM0->M0_FAX), " ", ""), "-", ""), "(", ""))
        cEmpFax := AllTrim(Transform(SM0->M0_FAX, "@r (99) 9999-9999"))
    EndIf

    // Municipio
    If !Empty(SM0->M0_CIDENT)
        cEmpMun := AllTrim(SM0->M0_CIDENT)
    ElseIf !Empty(SM0->M0_CIDCOB)
        cEmpMun := AllTrim(SM0->M0_CIDCOB)
    Else
        cEmpMun := "Sorocaba"
    EndIf

    // UF
    If !Empty(SM0->M0_ESTENT)
        cEmpUf := AllTrim(SM0->M0_ESTENT)
    ElseIf !Empty(SM0->M0_ESTCOB)
        cEmpUf := AllTrim(SM0->M0_ESTCOB)
    Else
        cEmpUf := "SP"
    EndIf

    // Bairro
    If !Empty(SM0->M0_BAIRENT)
        cEmpBairro := AllTrim(SM0->M0_BAIRENT)
    ElseIf !Empty(SM0->M0_BAIRCOB)
        cEmpBairro := AllTrim(SM0->M0_BAIRCOB)
    Else
        cEmpBairro := "Cajuru do Sul"
    EndIf

    // Logradouro (evita duplicar a cidade se o campo tiver so o nome da cidade)
    If !Empty(SM0->M0_ENDENT) .And. !(Upper(AllTrim(SM0->M0_ENDENT)) == Upper(cEmpMun))
        cEmpLogra := AllTrim(SM0->M0_ENDENT)
    ElseIf !Empty(SM0->M0_ENDCOB) .And. !(Upper(AllTrim(SM0->M0_ENDCOB)) == Upper(cEmpMun))
        cEmpLogra := AllTrim(SM0->M0_ENDCOB)
    Else
        cEmpLogra := "Av. Parana, 852"
    EndIf

    // CEP
    If !Empty(SM0->M0_CEPENT)
        cEmpCep := AllTrim(Transform(SM0->M0_CEPENT, "@r 99999-999"))
    ElseIf !Empty(SM0->M0_CEPCOB)
        cEmpCep := AllTrim(Transform(SM0->M0_CEPCOB, "@r 99999-999"))
    Else
        cEmpCep := "18105-000"
    EndIf

    If !Empty(cEmpBairro)
        cEmpEnd := cEmpLogra + " - " + cEmpBairro
    Else
        cEmpEnd := cEmpLogra
    EndIf
    cEmpCid := cEmpMun + " - " + cEmpUf + " | CEP: " + cEmpCep

    If !Empty(cEmpFax)
        cTelHeader := cEmpTel + " | <strong>Fax:</strong> " + cEmpFax
    Else
        cTelHeader := cEmpTel
    EndIf

    // =========================================================================
    // 1. LOGOTIPO (100% INDEPENDENTE DA MAQUINA DO USUARIO)
    // =========================================================================
    cLogoSrc := GetLogoDataUri()

    // =========================================================================
    // 2. DADOS DO CLIENTE E CONDICOES COMERCIAIS
    // =========================================================================
    SA1->(DbSetOrder(1))
    If SA1->(DbSeek(xFilial("SA1") + SCJ->CJ_CLIENTE + SCJ->CJ_LOJA))
        aEnd      := MyGetEnd(SA1->A1_END, "SA1")
        cRazao    := AllTrim(SA1->A1_NOME)
        cEnd      := AllTrim(aEnd[1])
        If aEnd[2] <> 0
            cNr := cValToChar(aEnd[2])
        Else
            cNr := "SN"
        EndIf
        If !Empty(cNr) .And. cNr != "SN"
            cEndComp := cEnd + ", " + cNr
        Else
            cEndComp := cEnd
        EndIf
        cBairro   := AllTrim(SA1->A1_BAIRRO)
        cCidade   := AllTrim(SA1->A1_MUN)
        cEstado   := SA1->A1_EST
        cCep      := AllTrim(Transform(SA1->A1_CEP, "@r 99999-999"))
        cCNPJ     := AllTrim(Transform(SA1->A1_CGC, "@r 99.999.999/9999-99"))
        cIE       := AllTrim(SA1->A1_INSCR)
        If !Empty(SA1->A1_CONTATO)
            cContato := AllTrim(SA1->A1_CONTATO)
        Else
            cContato := ""
        EndIf
        cTelCli   := "(" + AllTrim(SA1->A1_DDD) + ") " + AllTrim(SA1->A1_TEL)
        cEmailCli := AllTrim(SA1->A1_EMAIL)
    Else
        MsgAlert("Cliente " + SCJ->CJ_CLIENTE + "/" + SCJ->CJ_LOJA + " nao localizado no cadastro (SA1). Os dados do cliente sairao em branco.", "Atencao")
    EndIf

    // Vendedor
    SA3->(DbSetOrder(1))
    If lxVend1 .And. SA3->(DbSeek(xFilial("SA3") + SCJ->CJ_XVEND1))
        cVendedor := AllTrim(SA3->A3_NOME)
    ElseIf lVend1 .And. SA3->(DbSeek(xFilial("SA3") + SCJ->CJ_VEND1))
        cVendedor := AllTrim(SA3->A3_NOME)
    ElseIf lVend .And. SA3->(DbSeek(xFilial("SA3") + SCJ->CJ_VEND))
        cVendedor := AllTrim(SA3->A3_NOME)
    EndIf

    // Transportadora
    SA4->(DbSetOrder(1))
    If lxTrans .And. SA4->(DbSeek(xFilial("SA4") + SCJ->CJ_XTRANSP))
        cTransp := AllTrim(SA4->A4_NOME)
    ElseIf lTransp .And. SA4->(DbSeek(xFilial("SA4") + SCJ->CJ_TRANSP))
        cTransp := AllTrim(SA4->A4_NOME)
    EndIf

    // Condicao de pagamento
    cCondPag := AllTrim(Posicione("SE4", 1, xFilial("SE4") + SCJ->CJ_CONDPAG, "E4_DESCRI"))

    // Tipo de frete
    If lxFrete
        If SCJ->CJ_XFRETE == "F"
            cTipoFre := "FOB - Conta Destinatario"
        Else
            cTipoFre := "CIF - Conta Remetente"
        EndIf
    ElseIf lTpFrete
        If SCJ->CJ_TPFRETE == "F"
            cTipoFre := "FOB - Conta Destinatario"
        Else
            cTipoFre := "CIF - Conta Remetente"
        EndIf
    Else
        cTipoFre := "Por Conta do Destinatario"
    EndIf

    // Observacoes gerais
    If lxOBS .And. !Empty(SCJ->CJ_XOBS)
        cObsGeral := AllTrim(SCJ->CJ_XOBS)
    EndIf

    // =========================================================================
    // 3. ITENS DO ORCAMENTO (SOMENTE IPI)
    // =========================================================================
    While SCK->(!Eof()) .And. SCK->(CK_FILIAL + CK_NUM) == SCJ->(CJ_FILIAL + CJ_NUM)

        nItemSeq++

        cDescProd := AllTrim(Posicione("SB1", 1, xFilial("SB1") + SCK->CK_PRODUTO, "B1_DESC"))
        If lCkUm .And. !Empty(SCK->CK_UM)
            cUM := SCK->CK_UM
        Else
            cUM := Posicione("SB1", 1, xFilial("SB1") + SCK->CK_PRODUTO, "B1_UM")
        EndIf

        lIpi    := .F.
        nIpi    := 0
        nVlrIpi := 0

        SF4->(DbSetOrder(1))
        If SF4->(DbSeek(xFilial("SF4") + SCK->CK_TES))
            If SF4->F4_IPI == "S" .Or. SF4->F4_CREDIPI == "S"
                nIpi := Posicione("SB1", 1, xFilial("SB1") + SCK->CK_PRODUTO, "B1_IPI")
                If nIpi > 0
                    lIpi    := .T.
                    nVlrIpi := Round((nIpi * SCK->CK_VALOR) / 100, 2)
                EndIf
            EndIf
        EndIf

        nTotalItem := SCK->CK_VALOR + nVlrIpi
        nTotProd   += SCK->CK_VALOR
        nTotIpi    += nVlrIpi

        cLinhasItens += "<tr class='item-row'>"
        cLinhasItens += "<td class='col-center col-seq'>" + StrZero(nItemSeq, 2) + "</td>"
        cLinhasItens += "<td class='col-left col-desc'>"
        cLinhasItens += "<div class='prod-nome'>" + cDescProd + "</div>"
        If lCkObs .And. !Empty(SCK->CK_OBS)
            cLinhasItens += "<div class='prod-obs'>Obs: " + AllTrim(SCK->CK_OBS) + "</div>"
        EndIf
        cLinhasItens += "</td>"
        cLinhasItens += "<td class='col-center col-um'>" + cUM + "</td>"
        cLinhasItens += "<td class='col-right col-qtd'>" + AllTrim(Transform(SCK->CK_QTDVEN, cPicQtd)) + "</td>"
        cLinhasItens += "<td class='col-right col-prc'>" + AllTrim(Transform(SCK->CK_PRCVEN, cPicPrc)) + "</td>"

        If lIpi
            cLinhasItens += "<td class='col-right col-ipi-aliq'>" + AllTrim(Transform(nIpi, cPicIpi)) + "%</td>"
            cLinhasItens += "<td class='col-right col-ipi-val'>" + AllTrim(Transform(nVlrIpi, cPicVal)) + "</td>"
        Else
            cLinhasItens += "<td class='col-right col-ipi-aliq text-muted'>-</td>"
            cLinhasItens += "<td class='col-right col-ipi-val text-muted'>0,00</td>"
        EndIf

        cLinhasItens += "<td class='col-right col-tot font-bold'>" + AllTrim(Transform(nTotalItem, cPicVal)) + "</td>"
        cLinhasItens += "</tr>" + CRLF

        SCK->(DbSkip())
    EndDo

    nTotFrete := SCJ->CJ_FRETE
    nTotGer   := nTotProd + nTotIpi + nTotFrete

    // =========================================================================
    // 4. DOCUMENTO HTML (COM SUPORTE ROBUSTO A QUEBRA DE PAGINA)
    // =========================================================================
    cHtml := "<!DOCTYPE html>" + CRLF
    cHtml += "<html lang='pt-BR'>" + CRLF
    cHtml += "<head>" + CRLF
    cHtml += "<meta charset='utf-8'>" + CRLF
    cHtml += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>" + CRLF
    cHtml += "<title>Orcamento de Venda " + SCJ->CJ_NUM + "</title>" + CRLF
    cHtml += "<style id='page-orientation-style'>" + CRLF
    cHtml += "@page { size: A4 " + cOrientCss + "; margin: 10mm 8mm; }" + CRLF
    cHtml += "</style>" + CRLF
    cHtml += "<style>" + CRLF
    cHtml += "* { box-sizing: border-box; margin: 0; padding: 0; }" + CRLF
    cHtml += "html, body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }" + CRLF
    cHtml += "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f1f5f9; color: #1e293b; font-size: 12.5px; line-height: 1.4; padding: 20px; }" + CRLF
    cHtml += ".action-bar { max-width: 1100px; margin: 0 auto 16px auto; display: flex; justify-content: space-between; align-items: center; background: #ffffff; padding: 12px 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); border: 1px solid #e2e8f0; gap: 16px; flex-wrap: wrap; }" + CRLF
    cHtml += ".action-left { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }" + CRLF
    cHtml += ".btn-print { background-color: #1e3a8a; color: #ffffff; border: none; padding: 9px 20px; border-radius: 6px; font-size: 13px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 8px; transition: background-color 0.15s; }" + CRLF
    cHtml += ".btn-print:hover { background-color: #172554; }" + CRLF
    cHtml += ".orientation-control { display: inline-flex; align-items: center; background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 6px; padding: 3px; gap: 2px; }" + CRLF
    cHtml += ".orientation-lbl { font-size: 11.5px; font-weight: 600; color: #475569; padding: 0 8px; }" + CRLF
    cHtml += ".btn-orient { background: transparent; border: none; padding: 5px 12px; border-radius: 4px; font-size: 12px; font-weight: 600; color: #475569; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; transition: all 0.15s; }" + CRLF
    cHtml += ".btn-orient:hover { color: #0f172a; }" + CRLF
    cHtml += ".btn-orient.active { background: #ffffff; color: #1e3a8a; box-shadow: 0 1px 2px rgba(0,0,0,0.1); }" + CRLF
    cHtml += ".file-tag { font-size: 11px; color: #64748b; }" + CRLF
    cHtml += ".quote-page { margin: 0 auto; background: #ffffff; padding: 22px 26px; border-radius: 8px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.06), 0 2px 4px -2px rgba(0,0,0,0.04); border: 1px solid #e2e8f0; transition: max-width 0.2s ease; }" + CRLF
    cHtml += ".quote-page.portrait-mode { max-width: 820px; }" + CRLF
    cHtml += ".quote-page.landscape-mode { max-width: 1100px; }" + CRLF
    cHtml += "table.doc-wrapper { width: 100%; border-collapse: collapse; border: none; }" + CRLF
    cHtml += "table.doc-wrapper > thead { display: table-header-group; }" + CRLF
    cHtml += "table.doc-wrapper > tbody { display: table-row-group; }" + CRLF
    cHtml += "table.doc-wrapper > tfoot { display: table-footer-group; }" + CRLF
    cHtml += "table.doc-wrapper > thead > tr > td, table.doc-wrapper > tbody > tr > td, table.doc-wrapper > tfoot > tr > td { padding: 0; border: none; vertical-align: top; }" + CRLF
    cHtml += ".header-card { display: flex; justify-content: space-between; align-items: stretch; border: 1px solid #cbd5e1; border-radius: 6px; margin-bottom: 12px; background: #ffffff; overflow: hidden; page-break-inside: avoid; break-inside: avoid; }" + CRLF
    cHtml += ".company-block { flex: 1; padding: 14px 18px; display: flex; gap: 16px; align-items: center; min-width: 0; }" + CRLF
    cHtml += ".logo-box { width: 95px; height: 80px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }" + CRLF
    cHtml += ".logo-img { max-height: 78px; max-width: 95px; width: auto; height: auto; object-fit: contain; display: block; }" + CRLF
    cHtml += ".company-details { flex: 1; min-width: 0; }" + CRLF
    cHtml += ".company-details h1 { font-size: 15px; font-weight: 700; color: #1e3a8a; margin-bottom: 3px; line-height: 1.2; }" + CRLF
    cHtml += ".company-details p { font-size: 11px; color: #334155; margin-bottom: 2px; line-height: 1.35; }" + CRLF
    cHtml += ".quote-badge-block { width: 255px; flex-shrink: 0; border-left: 1px solid #cbd5e1; background: #f8fafc; display: flex; flex-direction: column; justify-content: space-between; }" + CRLF
    cHtml += ".badge-title { background: #1e3a8a; color: #ffffff; font-size: 12px; font-weight: 700; text-align: center; padding: 6px 10px; letter-spacing: 0.5px; }" + CRLF
    cHtml += ".badge-num-box { padding: 8px 12px; text-align: center; border-bottom: 1px solid #e2e8f0; }" + CRLF
    cHtml += ".badge-num-lbl { font-size: 10px; color: #64748b; font-weight: 600; text-transform: uppercase; }" + CRLF
    cHtml += ".badge-num-val { font-size: 22px; font-weight: 800; color: #1e3a8a; line-height: 1.1; margin-top: 2px; }" + CRLF
    cHtml += ".badge-meta { padding: 6px 12px; display: grid; grid-template-columns: 1fr 1fr; gap: 3px 8px; font-size: 10.5px; }" + CRLF
    cHtml += ".badge-meta div { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }" + CRLF
    cHtml += ".badge-meta span { color: #64748b; }" + CRLF
    cHtml += ".badge-meta strong { color: #0f172a; }" + CRLF
    cHtml += ".cards-row { display: grid; grid-template-columns: 63% 35%; justify-content: space-between; margin-bottom: 12px; page-break-inside: avoid; break-inside: avoid; }" + CRLF
    cHtml += ".data-card { border: 1px solid #cbd5e1; border-radius: 6px; overflow: hidden; background: #ffffff; page-break-inside: avoid; break-inside: avoid; }" + CRLF
    cHtml += ".card-header { background: #f1f5f9; border-bottom: 1px solid #cbd5e1; font-size: 11px; font-weight: 700; color: #1e3a8a; padding: 6px 12px; text-transform: uppercase; letter-spacing: 0.4px; }" + CRLF
    cHtml += ".card-body { padding: 9px 12px; font-size: 11px; }" + CRLF
    cHtml += ".grid-2col { display: grid; grid-template-columns: 57% 41%; justify-content: space-between; gap: 5px 10px; }" + CRLF
    cHtml += ".grid-1col { display: flex; flex-direction: column; gap: 5px; }" + CRLF
    cHtml += ".field-item { display: flex; align-items: baseline; gap: 5px; min-width: 0; }" + CRLF
    cHtml += ".field-lbl { color: #64748b; font-weight: 600; flex-shrink: 0; }" + CRLF
    cHtml += ".field-val { color: #0f172a; font-weight: 500; word-break: break-word; overflow-wrap: anywhere; }" + CRLF
    cHtml += ".table-container { margin-bottom: 12px; }" + CRLF
    cHtml += "table.items-table { width: 100%; border-collapse: collapse; font-size: 11px; border: 1px solid #cbd5e1; }" + CRLF
    cHtml += "table.items-table thead { display: table-header-group; }" + CRLF
    cHtml += "table.items-table tbody { display: table-row-group; }" + CRLF
    cHtml += "table.items-table tr { page-break-inside: avoid; break-inside: avoid; }" + CRLF
    cHtml += "table.items-table thead tr { background: #1e3a8a; color: #ffffff; }" + CRLF
    cHtml += "table.items-table th { padding: 8px 8px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; font-size: 10.5px; color: #ffffff; border: 1px solid #1e3a8a; }" + CRLF
    cHtml += "table.items-table tbody tr { border-bottom: 1px solid #cbd5e1; }" + CRLF
    cHtml += "table.items-table tbody tr:nth-child(even) { background-color: #f8fafc; }" + CRLF
    cHtml += "table.items-table tbody tr:hover { background-color: #f1f5f9; }" + CRLF
    cHtml += "table.items-table td { padding: 7px 8px; vertical-align: middle; border-left: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0; }" + CRLF
    cHtml += ".col-center { text-align: center; }" + CRLF
    cHtml += ".col-left { text-align: left; }" + CRLF
    cHtml += ".col-right { text-align: right; white-space: nowrap; }" + CRLF
    cHtml += ".col-seq { width: 5%; font-weight: 600; }" + CRLF
    cHtml += ".col-desc { width: 44%; }" + CRLF
    cHtml += ".col-um { width: 5%; }" + CRLF
    cHtml += ".col-qtd { width: 10%; }" + CRLF
    cHtml += ".col-prc { width: 11%; }" + CRLF
    cHtml += ".col-ipi-aliq { width: 6%; }" + CRLF
    cHtml += ".col-ipi-val { width: 8%; }" + CRLF
    cHtml += ".col-tot { width: 11%; color: #1e3a8a; font-weight: 700; }" + CRLF
    cHtml += ".prod-nome { font-weight: 600; color: #000000; font-size: 11.5px; word-break: break-word; }" + CRLF
    cHtml += ".prod-obs { font-size: 10.5px; color: #334155; font-style: italic; margin-top: 2px; word-break: break-word; }" + CRLF
    cHtml += ".font-bold { font-weight: 700; }" + CRLF
    cHtml += ".text-muted { color: #64748b; }" + CRLF
    cHtml += ".footer-section { page-break-inside: avoid; break-inside: avoid; margin-top: 4px; }" + CRLF
    cHtml += ".footer-cards { display: grid; grid-template-columns: 58% 40%; justify-content: space-between; margin-bottom: 10px; page-break-inside: avoid; break-inside: avoid; }" + CRLF
    cHtml += ".terms-box p { margin-bottom: 4px; color: #334155; font-size: 11px; }" + CRLF
    cHtml += ".signature-area { margin-top: 24px; text-align: center; }" + CRLF
    cHtml += ".sig-line { width: 78%; margin: 0 auto 4px auto; border-top: 1px solid #475569; }" + CRLF
    cHtml += ".sig-label { font-size: 10px; color: #64748b; font-weight: 600; text-transform: uppercase; }" + CRLF
    cHtml += ".totals-box { display: flex; flex-direction: column; gap: 5px; }" + CRLF
    cHtml += ".total-row { display: flex; justify-content: space-between; font-size: 11.5px; padding: 2px 4px; }" + CRLF
    cHtml += ".total-row .lbl { color: #64748b; font-weight: 600; }" + CRLF
    cHtml += ".total-row .val { color: #0f172a; font-weight: 600; }" + CRLF
    cHtml += ".grand-total { margin-top: 4px; padding: 8px 12px; background: #eff6ff; border: 1.5px solid #1e3a8a; border-radius: 6px; display: flex; justify-content: space-between; align-items: center; }" + CRLF
    cHtml += ".grand-total .lbl { font-size: 12px; font-weight: 800; color: #1e3a8a; text-transform: uppercase; }" + CRLF
    cHtml += ".grand-total .val { font-size: 16px; font-weight: 800; color: #1e3a8a; }" + CRLF
    cHtml += ".audit-bar { display: flex; justify-content: space-between; font-size: 10px; color: #64748b; padding-top: 6px; border-top: 1px solid #cbd5e1; page-break-inside: avoid; break-inside: avoid; }" + CRLF
    cHtml += "@media print {" + CRLF
    cHtml += "* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }" + CRLF
    cHtml += "html, body { background: #ffffff !important; padding: 0 !important; margin: 0 !important; color: #000000 !important; font-size: 10.5px !important; width: 100% !important; }" + CRLF
    cHtml += ".action-bar { display: none !important; }" + CRLF
    cHtml += ".quote-page, .quote-page.portrait-mode, .quote-page.landscape-mode { box-shadow: none !important; border: none !important; max-width: 100% !important; width: 100% !important; padding: 0 !important; margin: 0 !important; }" + CRLF
    cHtml += ".header-card { border: 1.2px solid #0f172a !important; margin-bottom: 8px !important; page-break-inside: avoid !important; break-inside: avoid !important; }" + CRLF
    cHtml += ".quote-badge-block { border-left: 1.2px solid #0f172a !important; }" + CRLF
    cHtml += ".cards-row { margin-bottom: 8px !important; page-break-inside: avoid !important; break-inside: avoid !important; }" + CRLF
    cHtml += ".data-card { border: 1.2px solid #0f172a !important; page-break-inside: avoid !important; break-inside: avoid !important; }" + CRLF
    cHtml += ".card-header { background-color: #f1f5f9 !important; color: #0f172a !important; border-bottom: 1.2px solid #0f172a !important; font-weight: 800 !important; padding: 5px 10px !important; }" + CRLF
    cHtml += ".table-container { margin-bottom: 8px !important; }" + CRLF
    cHtml += "table.items-table { border: 1.2px solid #0f172a !important; page-break-inside: auto !important; break-inside: auto !important; }" + CRLF
    cHtml += "table.items-table thead { display: table-header-group !important; }" + CRLF
    cHtml += "table.items-table tr { page-break-inside: avoid !important; break-inside: avoid !important; }" + CRLF
    cHtml += "table.items-table thead tr { background-color: #e2e8f0 !important; border-bottom: 1.5px solid #0f172a !important; }" + CRLF
    cHtml += "table.items-table th { background-color: #e2e8f0 !important; color: #0f172a !important; font-weight: 800 !important; font-size: 10px !important; border: 1px solid #0f172a !important; padding: 6px 5px !important; }" + CRLF
    cHtml += "table.items-table td { color: #000000 !important; border-bottom: 1px solid #94a3b8 !important; border-left: 1px solid #cbd5e1 !important; border-right: 1px solid #cbd5e1 !important; padding: 5px 6px !important; }" + CRLF
    cHtml += ".prod-nome { color: #000000 !important; font-weight: 700 !important; font-size: 10.5px !important; }" + CRLF
    cHtml += ".prod-obs { color: #1e293b !important; font-style: italic !important; font-size: 9.5px !important; }" + CRLF
    cHtml += ".col-tot { color: #000000 !important; font-weight: 700 !important; }" + CRLF
    cHtml += ".text-muted { color: #334155 !important; }" + CRLF
    cHtml += ".badge-title { background: #0f172a !important; color: #ffffff !important; }" + CRLF
    cHtml += ".footer-section, .footer-cards { page-break-inside: avoid !important; break-inside: avoid !important; }" + CRLF
    cHtml += ".grand-total { background: #f8fafc !important; border: 1.5px solid #0f172a !important; }" + CRLF
    cHtml += ".grand-total .lbl, .grand-total .val { color: #0f172a !important; }" + CRLF
    cHtml += "}" + CRLF
    cHtml += "</style>" + CRLF
    cHtml += "</head>" + CRLF
    cHtml += "<body>" + CRLF
    cHtml += "<div class='action-bar'>" + CRLF
    cHtml += "<div class='action-left'>" + CRLF
    cHtml += "<button class='btn-print' onclick='window.print()'>&#128438; Imprimir / Salvar em PDF</button>" + CRLF
    cHtml += "<div class='orientation-control'>" + CRLF
    cHtml += "<span class='orientation-lbl'>Orientacao:</span>" + CRLF
    cHtml += "<button id='btn-portrait' class='btn-orient " + cBtnPortAct + "' onclick='setPortrait()'>&#128196; Retrato</button>" + CRLF
    cHtml += "<button id='btn-landscape' class='btn-orient " + cBtnLandAct + "' onclick='setLandscape()'>&#128209; Paisagem</button>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<span class='file-tag'>Arquivo gravado em: <strong>" + cArquivo + "</strong></span>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<div class='quote-page " + cPageMode + "'>" + CRLF

    // Wrapper em tabela para repetir o cabecalho da empresa/proposta em todas as paginas impressas
    cHtml += "<table class='doc-wrapper'>" + CRLF
    cHtml += "<thead>" + CRLF
    cHtml += "<tr><td>" + CRLF

    // 1. Cabecalho (repete automaticamente em quebras de pagina)
    cHtml += "<div class='header-card'>" + CRLF
    cHtml += "<div class='company-block'>" + CRLF
    cHtml += "<div class='logo-box'>" + CRLF
    cHtml += "<img src='" + cLogoSrc + "' alt='Logo RewPlastic' class='logo-img' />" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<div class='company-details'>" + CRLF
    cHtml += "<h1>" + cEmpNome + "</h1>" + CRLF
    cHtml += "<p><strong>CNPJ:</strong> " + cEmpCnpj + " &nbsp;|&nbsp; <strong>I.E.:</strong> " + cEmpInsc + "</p>" + CRLF
    cHtml += "<p>" + cEmpEnd + "</p>" + CRLF
    cHtml += "<p>" + cEmpCid + "</p>" + CRLF
    cHtml += "<p><strong>Telefone:</strong> " + cTelHeader + " &nbsp;|&nbsp; <strong>Site:</strong> www.rewplastic.com.br</p>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<div class='quote-badge-block'>" + CRLF
    cHtml += "<div class='badge-title'>ORCAMENTO DE VENDA</div>" + CRLF
    cHtml += "<div class='badge-num-box'>" + CRLF
    cHtml += "<div class='badge-num-lbl'>Numero da Proposta</div>" + CRLF
    cHtml += "<div class='badge-num-val'>" + SCJ->CJ_NUM + "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<div class='badge-meta'>" + CRLF
    cHtml += "<div><span>Emissao:</span> <strong>" + DToC(SCJ->CJ_EMISSAO) + "</strong></div>" + CRLF
    cHtml += "<div><span>Validade:</span> <strong>3 Dias Uteis</strong></div>" + CRLF
    cHtml += "<div><span>Hora:</span> <strong>" + Time() + "</strong></div>" + CRLF
    cHtml += "<div title='" + cVendedor + "'><span>Vend.:</span> <strong>" + cVendedor + "</strong></div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF

    cHtml += "</td></tr>" + CRLF
    cHtml += "</thead>" + CRLF
    cHtml += "<tbody>" + CRLF
    cHtml += "<tr><td>" + CRLF

    // 2. Cliente e condicoes comerciais
    cHtml += "<div class='cards-row'>" + CRLF
    cHtml += "<div class='data-card'>" + CRLF
    cHtml += "<div class='card-header'>Dados do Destinatario / Cliente</div>" + CRLF
    cHtml += "<div class='card-body grid-2col'>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Razao Social:</span><span class='field-val'>" + cRazao + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>CNPJ/CPF:</span><span class='field-val'>" + cCNPJ + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Contato:</span><span class='field-val'>" + cContato + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Insc. Estadual:</span><span class='field-val'>" + cIE + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Endereco:</span><span class='field-val'>" + cEndComp + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Bairro:</span><span class='field-val'>" + cBairro + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Cidade/UF:</span><span class='field-val'>" + cCidade + " - " + cEstado + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>CEP:</span><span class='field-val'>" + cCep + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Telefone:</span><span class='field-val'>" + cTelCli + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>E-mail:</span><span class='field-val'>" + cEmailCli + "</span></div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<div class='data-card'>" + CRLF
    cHtml += "<div class='card-header'>Condicoes Comerciais e Fornecimento</div>" + CRLF
    cHtml += "<div class='card-body grid-1col'>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Cond. Pagto.:</span><span class='field-val'>" + cCondPag + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Transportadora:</span><span class='field-val'>" + cTransp + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Tipo de Frete:</span><span class='field-val'>" + cTipoFre + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Vendedor:</span><span class='field-val'>" + cVendedor + "</span></div>" + CRLF
    cHtml += "<div class='field-item'><span class='field-lbl'>Identificacao:</span><span class='field-val'>" + cNumLacre + "</span></div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF

    // 3. Tabela de itens (sem overflow:hidden para permitir repeticao do thead na quebra de pagina)
    cHtml += "<div class='table-container'>" + CRLF
    cHtml += "<table class='items-table'>" + CRLF
    cHtml += "<thead>" + CRLF
    cHtml += "<tr>" + CRLF
    cHtml += "<th class='col-center col-seq'>Item</th>" + CRLF
    cHtml += "<th class='col-left col-desc'>Descricao do Produto / Servico</th>" + CRLF
    cHtml += "<th class='col-center col-um'>UM</th>" + CRLF
    cHtml += "<th class='col-right col-qtd'>Quantidade</th>" + CRLF
    cHtml += "<th class='col-right col-prc'>Preco Unit.</th>" + CRLF
    cHtml += "<th class='col-right col-ipi-aliq'>% IPI</th>" + CRLF
    cHtml += "<th class='col-right col-ipi-val'>Valor IPI</th>" + CRLF
    cHtml += "<th class='col-right col-tot'>Total Item</th>" + CRLF
    cHtml += "</tr>" + CRLF
    cHtml += "</thead>" + CRLF
    cHtml += "<tbody>" + CRLF
    cHtml += cLinhasItens
    cHtml += "</tbody>" + CRLF
    cHtml += "</table>" + CRLF
    cHtml += "</div>" + CRLF

    // 4. Rodape: termos, resumo financeiro e barra de auditoria (agrupados para nao cortar no meio)
    cHtml += "<div class='footer-section'>" + CRLF
    cHtml += "<div class='footer-cards'>" + CRLF
    cHtml += "<div class='data-card terms-box'>" + CRLF
    cHtml += "<div class='card-header'>Informacoes Gerais e Aceite da Proposta</div>" + CRLF
    cHtml += "<div class='card-body'>" + CRLF
    cHtml += "<p>Em caso de confirmacao, favor retornar assinado ou responder o e-mail com <strong>'Orcamento Aprovado'</strong>.</p>" + CRLF
    cHtml += "<p>Precos e prazos de entrega validos durante a vigencia desta proposta comercial (3 dias uteis).</p>" + CRLF
    If !Empty(cObsGeral)
        cHtml += "<p><strong>Obs. Geral:</strong> " + cObsGeral + "</p>" + CRLF
    EndIf
    cHtml += "<div class='signature-area'>" + CRLF
    cHtml += "<div class='sig-line'></div>" + CRLF
    cHtml += "<div class='sig-label'>De Acordo / Assinatura do Cliente &bull; Data: ____/____/________</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "<div class='data-card'>" + CRLF
    cHtml += "<div class='card-header'>Resumo Financeiro do Orcamento</div>" + CRLF
    cHtml += "<div class='card-body totals-box'>" + CRLF
    cHtml += "<div class='total-row'><span class='lbl'>Total dos Produtos:</span><span class='val'>" + AllTrim(Transform(nTotProd, cPicVal)) + "</span></div>" + CRLF
    cHtml += "<div class='total-row'><span class='lbl'>Total do IPI:</span><span class='val'>" + AllTrim(Transform(nTotIpi, cPicVal)) + "</span></div>" + CRLF
    cHtml += "<div class='total-row'><span class='lbl'>Valor do Frete:</span><span class='val'>" + AllTrim(Transform(nTotFrete, cPicFre)) + "</span></div>" + CRLF
    cHtml += "<div class='grand-total'>" + CRLF
    cHtml += "<span class='lbl'>TOTAL DO ORCAMENTO:</span>" + CRLF
    cHtml += "<span class='val'>" + AllTrim(Transform(nTotGer, cPicVal)) + "</span>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF

    // 5. Barra de auditoria
    cHtml += "<div class='audit-bar'>" + CRLF
    cHtml += "<span>Protheus ERP - Faturamento</span>" + CRLF
    cHtml += "<span>Emitido em: " + DToC(dDataBase) + " as " + Time() + "</span>" + CRLF
    cHtml += "</div>" + CRLF
    cHtml += "</div>" + CRLF

    cHtml += "</td></tr>" + CRLF
    cHtml += "</tbody>" + CRLF
    cHtml += "</table>" + CRLF
    cHtml += "</div>" + CRLF

    cHtml += "<script>" + CRLF
    cHtml += "function setPortrait() {" + CRLF
    cHtml += "  var style = document.getElementById('page-orientation-style');" + CRLF
    cHtml += "  var btnP = document.getElementById('btn-portrait');" + CRLF
    cHtml += "  var btnL = document.getElementById('btn-landscape');" + CRLF
    cHtml += "  var page = document.querySelector('.quote-page');" + CRLF
    cHtml += "  style.innerHTML = '@page { size: A4 portrait; margin: 10mm 8mm; }';" + CRLF
    cHtml += "  btnP.classList.add('active');" + CRLF
    cHtml += "  btnL.classList.remove('active');" + CRLF
    cHtml += "  page.classList.remove('landscape-mode');" + CRLF
    cHtml += "  page.classList.add('portrait-mode');" + CRLF
    cHtml += "}" + CRLF
    cHtml += "function setLandscape() {" + CRLF
    cHtml += "  var style = document.getElementById('page-orientation-style');" + CRLF
    cHtml += "  var btnP = document.getElementById('btn-portrait');" + CRLF
    cHtml += "  var btnL = document.getElementById('btn-landscape');" + CRLF
    cHtml += "  var page = document.querySelector('.quote-page');" + CRLF
    cHtml += "  style.innerHTML = '@page { size: A4 landscape; margin: 10mm 8mm; }';" + CRLF
    cHtml += "  btnL.classList.add('active');" + CRLF
    cHtml += "  btnP.classList.remove('active');" + CRLF
    cHtml += "  page.classList.remove('portrait-mode');" + CRLF
    cHtml += "  page.classList.add('landscape-mode');" + CRLF
    cHtml += "}" + CRLF
    cHtml += "</script>" + CRLF
    cHtml += "</body>" + CRLF
    cHtml += "</html>" + CRLF

    // =========================================================================
    // 5. GRAVACAO DO ARQUIVO (UTF-8) NA PASTA %TEMP% DO USUARIO
    // =========================================================================
    If FindFunction("EncodeUTF8")
        cHtml := EncodeUTF8(cHtml)
    EndIf

    nHandle := FCreate(cArquivo)
    If nHandle >= 0
        FWrite(nHandle, cHtml)
        FClose(nHandle)
    Else
        MemoWrite(cArquivo, cHtml)
    EndIf

    // Abre no navegador padrao
    ShellExecute("open", cArquivo, "", "", 1)

    // =========================================================================
    // 6. ENVIO POR E-MAIL (SE SOLICITADO)
    // =========================================================================
    If lEmail
        EnvMail(cArquivo + ";", SCJ->CJ_NUM)
    EndIf

Return Nil

/*/{Protheus.doc} GetLogoDataUri
    Obtem o logotipo como Data URI Base64 de forma 100% independente da maquina do usuario.
    Prioriza a leitura binaria de arquivo no servidor (se existir) e utiliza o logotipo
    oficial da RewPlastic embutido em Base64 no proprio fonte como garantia absoluta.
    @type   Static Function
    @return Character, Data URI completa da imagem (data:image/...;base64,...)
/*/
Static Function GetLogoDataUri()

    Local cStartPath  := AllTrim(GetSrvProfString("Startpath", "\system\"))
    Local aCandidatos := {}
    Local cLogoSrv    := ""
    Local cLogoMime   := "image/png"
    Local cLogoBase64 := ""
    Local cExt        := ""
    Local cBufLogo    := ""
    Local cDataUri    := ""
    Local nIdx        := 0
    Local nHLogo      := -1
    Local nTamLogo    := 0
    Local nLidos      := 0

    If Empty(cStartPath)
        cStartPath := "\system\"
    EndIf
    If !(Right(cStartPath, 1) $ "\/")
        cStartPath += "\"
    EndIf

    AAdd(aCandidatos, cStartPath + "lgmid.png")
    AAdd(aCandidatos, cStartPath + "lgmid.jpg")
    AAdd(aCandidatos, cStartPath + "lgmid.bmp")
    AAdd(aCandidatos, cStartPath + "lgrl" + AllTrim(cEmpAnt) + ".bmp")
    AAdd(aCandidatos, cStartPath + "lgrl01.bmp")
    AAdd(aCandidatos, "\system\lgmid.png")
    AAdd(aCandidatos, "\system\lgmid.jpg")
    AAdd(aCandidatos, "\system\lgmid.bmp")
    AAdd(aCandidatos, "\system\lgrl01.bmp")

    For nIdx := 1 To Len(aCandidatos)
        If File(aCandidatos[nIdx])
            cLogoSrv := aCandidatos[nIdx]
            Exit
        EndIf
    Next nIdx

    If !Empty(cLogoSrv)
        cExt := Upper(Right(AllTrim(cLogoSrv), 4))
        If cExt == ".JPG" .Or. Upper(Right(AllTrim(cLogoSrv), 5)) == ".JPEG"
            cLogoMime := "image/jpeg"
        ElseIf cExt == ".BMP"
            cLogoMime := "image/bmp"
        Else
            cLogoMime := "image/png"
        EndIf

        // Leitura binaria segura via FOpen/FRead + Encode64(cBufLogo)
        If FindFunction("Encode64")
            nHLogo := FOpen(cLogoSrv, 0)
            If nHLogo >= 0
                nTamLogo := FSeek(nHLogo, 0, 2)
                FSeek(nHLogo, 0, 0)
                If nTamLogo > 0
                    cBufLogo := Space(nTamLogo)
                    nLidos   := FRead(nHLogo, @cBufLogo, nTamLogo)
                    If nLidos == nTamLogo
                        cLogoBase64 := Encode64(cBufLogo)
                    EndIf
                EndIf
                FClose(nHLogo)
            EndIf
        EndIf

        If !Empty(cLogoBase64)
            cLogoBase64 := StrTran(cLogoBase64, Chr(13), "")
            cLogoBase64 := StrTran(cLogoBase64, Chr(10), "")
            cLogoBase64 := StrTran(cLogoBase64, " ", "")
            cDataUri    := "data:" + cLogoMime + ";base64," + cLogoBase64
        EndIf
    EndIf

    // Garantia absoluta: se o arquivo nao foi encontrado ou nao pode ser lido no servidor,
    // utiliza o logotipo oficial da RewPlastic embutido diretamente no codigo-fonte
    If Empty(cDataUri)
        cDataUri := GetLogoEmbutido()
    EndIf

Return cDataUri

/*/{Protheus.doc} MyGetEnd
    Tratamento de endereco para retorno correto de logradouro e numero
    @type  Static Function
    @author Liber De Esteban
/*/
Static Function MyGetEnd(cEndereco, cAlias)

    Local cCmpEndN := SubStr(cAlias, 2, 2) + "_ENDNOT"
    Local cCmpEst  := SubStr(cAlias, 2, 2) + "_EST"
    Local aRet     := {"", 0, "", ""}

    If (&(cAlias + "->" + cCmpEst) == "DF") .Or. ((cAlias)->(FieldPos(cCmpEndN)) > 0 .And. &(cAlias + "->" + cCmpEndN) == "1")
        aRet[1] := cEndereco
        aRet[3] := "SN"
    Else
        aRet := FisGetEnd(cEndereco)
    EndIf

Return aRet

/*/{Protheus.doc} EnvMail
    Interface e envio de e-mail com anexo do orcamento HTML
    @type  Static Function
/*/
Static Function EnvMail(cAnexo, cOrc)

    Local oDlgMail    as Object
    Local oPara       as Object
    Local oCC         as Object
    Local lHasXVend1  := SCJ->(FieldPos("CJ_XVEND1")) > 0
    Local cNomeVend   := ""
    Local cMailVend   := ""

    Private mCorpo    := ""
    Private cAssunto  := "Orcamento - " + AllTrim(SA1->A1_NOME) + " - No. " + cOrc
    Private cServer   := Trim(GetMV("MV_RELSERV"))
    Private cDe       := Trim(GetMV("MV_RELACNT"))
    Private cPass     := Trim(GetMV("MV_RELPSW"))
    Private lAutentic := GetMv("MV_RELAUTH", , .F.)
    Private cPara     := SA1->A1_EMAIL
    Private cCC       := ""
    Private lConectou := .F.
    Private lRet      := .F.
    Private lEnviado  := .F.
    Private cMensagem := ""

    If lHasXVend1
        cNomeVend := Capital(Posicione("SA3", 1, xFilial("SA3") + SCJ->CJ_XVEND1, "A3_NOME"))
        cMailVend := Posicione("SA3", 1, xFilial("SA3") + SCJ->CJ_XVEND1, "A3_EMAIL")
        cCC       := cMailVend
    EndIf

    mCorpo += "Segue em anexo a proposta comercial do Orcamento: " + cOrc + Chr(13) + Chr(10) + Chr(13) + Chr(10)
    mCorpo += "Ficamos a disposicao para quaisquer esclarecimentos." + Chr(13) + Chr(10) + Chr(13) + Chr(10)
    mCorpo += "Atenciosamente," + Chr(13) + Chr(10)
    mCorpo += cNomeVend + Chr(13) + Chr(10)
    mCorpo += cMailVend + Chr(13) + Chr(10)
    mCorpo += "Departamento Comercial" + Chr(13) + Chr(10)
    mCorpo += "Site: www.rewplastic.com.br" + Chr(13) + Chr(10)

    DEFINE MSDIALOG oDlgMail FROM 122, 67 TO 531, 733 TITLE OemToAnsi("Envio de E-Mail") PIXEL
    @ 002, 004 TO 078, 324 OF oDlgMail PIXEL
    @ 080, 004 TO 182, 324 OF oDlgMail PIXEL
    @ 011, 015 SAY OemToAnsi("De :")      SIZE 030, 008 OF oDlgMail PIXEL
    @ 023, 015 SAY OemToAnsi("Para :")    SIZE 025, 008 OF oDlgMail PIXEL
    @ 035, 015 SAY OemToAnsi("CC :")      SIZE 030, 008 OF oDlgMail PIXEL
    @ 047, 015 SAY OemToAnsi("Assunto :") SIZE 030, 008 OF oDlgMail PIXEL
    @ 059, 015 SAY OemToAnsi("Anexos :")  SIZE 030, 008 OF oDlgMail PIXEL
    @ 010, 040 MSGET cDe      SIZE 270, 010 OF oDlgMail PIXEL WHEN .F.
    @ 022, 040 MSGET oPara VAR cPara SIZE 270, 010 OF oDlgMail PIXEL
    @ 034, 040 MSGET oCC   VAR cCC   SIZE 270, 010 OF oDlgMail PIXEL
    @ 046, 040 MSGET cAssunto SIZE 270, 010 OF oDlgMail PIXEL
    @ 058, 040 MSGET cAnexo   SIZE 270, 010 OF oDlgMail PIXEL
    @ 088, 009 GET mCorpo MEMO SIZE 310, 090 OF oDlgMail PIXEL
    @ 187, 276 BUTTON OemToAnsi("_Enviar") SIZE 036, 016 OF oDlgMail PIXEL ACTION ValidDest(oDlgMail, cPara)
    ACTIVATE MSDIALOG oDlgMail CENTERED

    SendSmtpMail(cServer, cDe, cPass, lAutentic, cPara, cCC, cAssunto, mCorpo, cAnexo, @lConectou, @lEnviado, @cMensagem)

    If ValType(oCC) == "O"
        oCC:Destroy()
    EndIf
    If ValType(oPara) == "O"
        oPara:Destroy()
    EndIf
    If ValType(oDlgMail) == "O"
        oDlgMail:Destroy()
    EndIf

Return Nil

/*/{Protheus.doc} ValidDest
    Valida se o destinatario do e-mail foi preenchido antes de fechar o dialogo
    @type  Static Function
/*/
Static Function ValidDest(oDlgMail, cPara)

    If !Empty(cPara)
        oDlgMail:End()
    Else
        FWAlertWarning("E-Mail sem destinatario!", "E-MAIL")
    EndIf

Return Nil

/*/{Protheus.doc} SendSmtpMail
    Realiza o envio do e-mail utilizando a classe moderna TMailManager / TMailMessage
    @type  Static Function
/*/
Static Function SendSmtpMail(cServer, cDe, cPass, lAutentic, cPara, cCC, cAssunto, mCorpo, cAnexo, lConectou, lEnviado, cMensagem)

    Local oServer  := TMailManager():New()
    Local oMessage := TMailMessage():New()
    Local nErro    := 0
    Local nPos     := 0
    Local cSrvAddr := AllTrim(cServer)
    Local nSrvPort := 25
    Local cArqAnx  := AllTrim(StrTran(cAnexo, ";", ""))

    nPos := At(":", cSrvAddr)
    If nPos > 0
        nSrvPort := Val(SubStr(cSrvAddr, nPos + 1))
        cSrvAddr := SubStr(cSrvAddr, 1, nPos - 1)
    EndIf

    oServer:Init("", cSrvAddr, cDe, cPass, 0, nSrvPort)
    oServer:SetSmtpTimeOut(60)

    nErro := oServer:SmtpConnect()
    If nErro == 0
        lConectou := .T.
        If lAutentic
            nErro := oServer:SmtpAuth(cDe, cPass)
        EndIf
        If nErro == 0
            oMessage:Clear()
            oMessage:cFrom    := AllTrim(cDe)
            oMessage:cTo      := AllTrim(cPara)
            oMessage:cCc      := AllTrim(cCC)
            oMessage:cSubject := AllTrim(cAssunto)
            oMessage:cBody    := mCorpo
            If !Empty(cArqAnx) .And. File(cArqAnx)
                oMessage:AttachFile(cArqAnx)
            EndIf
            nErro := oMessage:Send(oServer)
            If nErro == 0
                lEnviado := .T.
            Else
                cMensagem := oServer:GetErrorString(nErro)
            EndIf
        Else
            cMensagem := oServer:GetErrorString(nErro)
        EndIf
        oServer:SmtpDisconnect()
    Else
        cMensagem := oServer:GetErrorString(nErro)
    EndIf

Return Nil

/*/{Protheus.doc} GetLogoEmbutido
    Retorna o Data URI (Base64) do logotipo oficial da RewPlastic (lgmid.png)
    embutido diretamente no codigo-fonte para garantir exibicao em qualquer estacao.
    @type   Static Function
    @return Character, Data URI Base64 da imagem PNG
/*/
Static Function GetLogoEmbutido()
    Local cB64 := "data:image/png;base64,"
    cB64 += "iVBORw0KGgoAAAANSUhEUgAAAJkAAACgCAYAAAAfKc7fAAAQAElEQVR4Aey9BYAdR5K1+2XVpeZWd4uZWbIFZpKZmZmZmZmZmdmyzJZsSxbYFlhsMTO01MyX"
    cB64 += "Ct6pK3vg3915sxp5aKdUcYsyIyMjT0ZERrZnLM/zfM/7D3nef3Tgeb+PDiz+c/xHA7+zBv4ryDwf46lVH3zfzxC612scY3B8gxEFRTwV9HEIrp7xdQUPg6dy"
    cB64 += "KqVy4qPT17uA0BXV5T/H/ykN/BnIjDGkXYe6ulo2rVzDimlzWfTdj6wfP5HaBQvxN20glKgm6dfjukl8V6DyQ5i0jeVYWHqW/8V2XYJ/acvDNS6W5wpwLnrK"
    cB64 += "PP+f0vB/Oov1pzrwZbnscJicgnxadmxPt+360XP3nTAtm7Hyl7n88PBzfHXypfx40NnMOvlKFt98DxveeJ3KCd/RtGQBfnUVvpMiLT4JEb5FKBUSuGx8NWU8"
    cB64 += "kwEi/zn+T2ngz0AW9Nz2wZZb88IWiZiFmxOlTa9+DD75RPZ99F4OHvEGuw9/gdbnHkkq32LZmO9YeN3dTD/iHGYfeCZrTruOytueJP7SR1R/M476FYvx62sg"
    cB64 += "nRLYfFKWlXHBAaCD9v5D//4a+C8gC0KmgEIeZMnyhKUDVw+u5RO8t60wsbwS2u1zANvdcBv7vPsRu/70Hf3eeQpz3O7MctYx8dM3WPrYIzTdeCe1p1/MskNO"
    cB64 += "ZPWJ57P+pnupfW84TdNn42zaBGm53MDiBQGfwO0L3MGj8dVo5pQQxsncBT/Ba0cfJRbBffBOj8Hl35f+DXr2X0D2W58CQAVk9CKkG1sAMKLg9AU4GSSMrY8i"
    cB64 += "Kyeboh2Hst1113LExyM4eMYkOrzxJBuO2IuJ4RRL582mYsxY7FfewVx7B+sOOpbF/fdi7vb7seKMi1n37Cs0TpyEu2k9XrKelJvGFdo8uVjXtxX4qWXhzRIY"
    cB64 += "w46PnUZu1yjOC4DvSQhf9J/zn1UD/yPItlZgYyxCWQW03mVPdr39Tk4YP55hC6cSfvUB5hw0lB+iLmVNtTgNFbiLZ1H10VtU3HAz6/c9nqUD9mPu3sew/rZ7"
    cB64 += "aPj0S9JLlmE1NclqucRtaLIt3dtaPBgcPbtaWKDVLXrLf45/Wg1sE5AZI6vyK1kGQpaLTA1p+dp01CandSf6nXAaB7zzNofPn0abrz9k88Vns7BLD8pDRTR5"
    cB64 += "DgtMFXNrV1AxbRI1Tz7PxnOvZOVeR7B2yIGsP+8aGl+QFZw9j1SiTjFdUrhKZ2I8tLoNMPafGO+fFmPyR9tcNoNvhTBaPoQ8i7C8mbEcwsp32PKvJreQzvvs"
    cB64 += "z36PPcRJc39k8MQv4NqLiPYZRIHdjKQs4ZJ0E9PrNjC3fCXLV8+levjbNF5zA6V7HsGqofuz8qLrqX71A7xfluDHEyhRjTwogp6AB/KqCOYEuTsyd1vcqdHF"
    cB64 += "/GlAx3+Ov4cGrN+jEUvxlAkYBz+ycAhwvsBjjCFsCJ6w9WzFcmm1/WAG33Mv+08ezeDRwym69AKiHTvQIlZAromwhARj47V8k6xkflM5yRWryH3zQ8wlt1C6"
    cB64 += "29Gs2OkQNlxyHYmPP8dasw6TSCtv5xOAyVEs6Wgeebp6QMpA2vIFPj385/y7aeB3Adn/VvqoXJ4dzaVk1z3Y9dFHOGLeVPoPf4NmRx1J51gbupsCsrBZ6zcx"
    cB64 += "ya/kO6+GH61aNptqslYsIfbe+zSeezmrhhzAsmHHsObhR2maPIlwVS2W48u9gnGNksQin8C78p/j76eBfwqQpUMOrlyqr0Des8FEC2l+8KHs8P5r7D3nR3o8"
    cB64 += "cS/Nhu5Ii2gzignLFUeoTvvMb2zgh0QNC+Ip6hMO+fXVFMz5mcJ7n6Bpv5NZusO+rDz7Iirefg9v7SpZuCY8z8N3A+BtoeCZ/xy/qwb+KUAW9kIEZAcIE4SM"
    cB64 += "ABcyLiZkE2nfjk4XXchB40YxbMwXtLnwQkJti8gKQwQotz1mWg2M9ioZ69SwUOmP9crrJaw0JetKKfxwJP7FN7J6yL6sOOA41t33II2TJ2IaG9WSLzIZ0yYP"
    cB64 += "Lwvni+OvJBcrCf7jWqWRv/X8pwCZMRrYX0lDDlogWNj6Z2VAoM0H7FiM4p13ZtenHuP4GZPp/8RDZO8wlKJQDs0Uu1lAre+w1G1kaqKKWak6luu+TiA0xqJZ"
    cB64 += "3KHl9Hk0e/glGo/QzsQOB1J62a3Ujh6HW1eD42i16vno1FLBZMBl6cG4YhwgUJf/nFungWBstq7m37GWMSbTmjFbruGi1vS+8HyOHD+K/b/4lK4HH05OdhEx"
    cB64 += "2bYkHg2+xzo/wWxbq9RUFYsFuPKQTyIWReaR7HSC/HVLib31DslTLmB1/73ZcM61VAz/FG/TZkJpR9YtTWZ3wQJPIP1PioStPqTCra77d61ozBaAGWNIhyxZ"
    cB64 += "uRBWKJeSffdk9+Hvcui47+h6/tnkNWtOzI7iqURSVqhaVmilG2d6UwU/1ZeywGqiPDsLL1xILGmTLQuXV7WJYu1UZJ97E0uG7sei486k/Nl3cJYvx0vFFcOl"
    cB64 += "tXjwM/R37fS/SWP/MiD7U32HlbzFODhhF2EOT1Yqb3Bf9nj2cU76eSo9LrkYWrTCaJGQFDbrLUO9rFu5n2RZUzVTqjYwxqlkVqsQDcVZhLwwSW1fxQXGVmXl"
    cB64 += "NB89Huve+ynf8xjWH3s2m199k9TKtRhXbf4hcvMl0h/pj3eohD795/yDBv4lQYZlqwM2Id9SFgxCiuEiJoSxw0Q6t2OPxx7gwumT6H/NFTitWivGskjpt1EB"
    cB64 += "Vq3nklasFY83Mkd7pZ9Wrmdmqxzq25VgxXLENyzLBaYuTqyujrxJM8m+/3k2HHAsa488m7pX3ye5YjlOsLkvsLsCr5wrQTCndWvG2hmtXvnP8QcNWH+4+683"
    cB64 += "/5JvLMvCllWiTSt2fvBOLp32M/2uu4K6liUCQFQ7AzY12vZKCSBZjqP4K8W8jat4d+0Cfmqhbz07ksorxA1HZLlcLK1C/c2liuHWEJ34A+lb72LzXkex5pgL"
    cB64 += "2fj2RzgbNhFKuLhadFiOK525JO3gqtv/nBkN/NuBLOiVE7K0BAgRcyNYbVqzxwP3c/WsX+hz3dUki/IIy/LFZQ0rIjaO8maFKZ9iP8KCFSt5fvFURpb41HTr"
    cB64 += "iJ1TgG8MceMTEi+vKY1bWUesopzCSWPJv/YBNuxxDMvPuJC6z78nVVstt+sTCXbvQaAOnKhu/o+f/5Ygs/AJEru+8mVhuciorEy0RTP2v/dOLp85k44XX0Sq"
    cB64 += "sAW5bracqE2l5ZD04uRpkdDWirFi+UqeXvgzo9rIsg3sCoUFJKM+2XLOeVaImFImNPrUNtQQLt9I0bSZePc+QNkhZ1J23f3UT5uKH1hAcUdLEHR4kkkXtlx8"
    cB64 += "3Qb06+XXWz39W57/niDToFm+UeBvNGjqouK1kBXGtkPktG/P4Y8/yjk/fEfeUQdRnR0lbSzBIZQBQNhNIWzRWhZuxqKFvDB7BjPatSA1ZACNzQpI2wYVJxLw"
    cB64 += "kjWMpV0S6zfSsGgx4bWraTZ+IvEr7mL1UedS/vTLJJcuwTQ14HsJHN/NpEUc4+IZ8CSdZ4za1oPu/11PjcC/a9f++34FMZvxLXJ7dueYD1/l9G++xt5xF6qj"
    cB64 += "MTyB0cia2a5LG7m83sTIE9hGz57KY6JFAzrTNGQgDVk5+MYn+Bfwi4Wj5Ko5V260csE8ksuWUFBfSf6Yn6k/83amn3MlZR9+ia/vQb4t5NpYroXRRLA0IWy1"
    cB64 += "qer/tqf1b9uz/6djxpjMm2CQnZAhZEfI8nLotMuuXPP9KA575gkaOnXEt7OIEiJluUS0RdXGg84mhNWU4J3x3/HM4uls2G0A9dv3EyiziAmMjpASDkXJ0WIh"
    cB64 += "TwuPUEM9dTNmsO6H73HLV9K3KUHWdz+w5oxbWHn9o9QpPnScJpJKqSSUikkbT4DNiPdv+WP9/r3SVP1fqvC3Gr9d/2YZxciXRfpNDKXVlKrVwNoOKB4z0SiD"
    cB64 += "zjyNayaPpsPFZ1KVna3vNmmBxyFNjoDQ2fZpadtsrK7kiZFfMLyugtqTD6CiU3OiskppAdFVvGYH4JVVzBHYookESeXXVo8eTfm4CRTmQdcci8RrH7L4vFso"
    cB64 += "f+tzwqWVWEp5BBv1GRn/N539Fyn7O4BMTkQxh4YP1wNXP75J42ugMi7G13dFIe6v5GSuPioq0tWAr9yTr1yW5xrVNzgCSEBpgSUlF9Mo5TapTFwxTkLXlHgm"
    cB64 += "xaBJdRo0YLWOT1XKpTKZpkJUnkhR1iRqTFCm/Fd5bZyK6gSVNSkqqtKiLc81FDL4hjsY9tEIGnYeRiqnGVnZ+bjhGEEurgU23QSk1urTzHmzuPv915jbuRWN"
    cB64 += "B+1NKjcL27dkAX0tD8BWncJQgXYfwkSchCzaBuo//Yo1z7xCeuFCOpa0IGvxChZedy9L73qc+Mz5mFRCOby0Um6edIGUZ3Tvk5aO1HW9+Nc8fweQGYQo5ZgS"
    cB64 += "zF2zkVd+WsbD49bz4Jg13Pfdcu75dhm3fbOWW0at4ZZv13Lr6HVcO3411/64husnrufGSRu5eepG7py5nvtmrubR2at57pdSXp9fxkcLNvPZ/I18N3c94xZs"
    cB64 += "YOKC9UxbJFq8nplLNzBv2UaWrNzM+tXllK2rpGJDDVUba6ktr6e2qoG6mibqGxI0CnRN2p8MKK7cVtJJ4TpxDXAyM6Ct5ArP+PgNTv9lMsdNm8KJ343hoHff"
    cB64 += "Zdh99zP41DPoscPOdCppixatvDrhW+6YPVory91p6tedAB0uDka7DKmIABeJUmQLbFaUJCnStZtITppI/QuvEP9eljPXpmVWhPoPv2DR5XdR+cnXuE2VGG3Y"
    cB64 += "p0IuTeJjKe9n/oVR9juADBzHZ4PcwCbllD56fwpP3v0hT90ruuddXd/m+ftf46UHX+clXV+871Xeu+013rv5Fd676RXevekl3tH9mze+yhuiV69/hRevf5nn"
    cB64 += "rnqBxy97hkcvfYr7L36euy98kTsueoVbL3yFWy56iRsveJ7rz3uea895hovOfprzzn6G8895lgvOfY6Lz36Wy89+jktFF531rL6/xCXnvcHlF77NlRe/x/VX"
    cB64 += "jeS2W6fx5BPz+PKzzcyclWR1dYx4iy6EenUnf5ftaXvs4Qy85jIOeelZzv/hW26aOZZLXn2JIfsexKqyOm58+x2+LbBxzjwCJ6eIrHSMLAdC+BitRIuUGsnP"
    cB64 += "ycER8Gr8JtZ4ZZTPn83GNz+k/rORuOl62vTuSk69z6r7P2TF8x+Q3rCBPMVznla8mbhNFvtf0ZZZv4fQtQ2NLJBFGfHmWCa/O5KySZMpnzyJyqlTqJ4+lbop"
    cB64 += "s3+lX6if8guV0xaIFlKua9nUBWyespjSn5exfuoq1k5bz/Jpq1k0Yx0L5pQxd0Et85ZUM3dZHTOXxZm63GHaCsOM1SGmrQ0xdUOE6ZuymLEpO0PTN+UwpTyf"
    cB64 += "nyoL+ammGVMam/NTQz7j68KMrbX4XjSmPMmYNbV8ObOaZz9aylV3TuTIE0ey6y5vsd9BX3DBNZN5+tX5TPmlmuqkwQmHiLbtzKCTT+Lmz0fw4rhxdN5hd1Ze"
    cB64 += "MwAAEABJREFUN94YO4F7P/2cspOPoGxoX2rDNiFPSFO44MrEFaRs2vj5tIgWk6U4rsZPUOHWsXHODMpfe4/Kb0dR+fNPFIVTdGzbjLIRo1jw9Gs0zJpHWKkS"
    cB64 += "BNjgDMbM/8NPcPPPTdsEZEZxkgIpuRyP+oY4k2fM44dxi3jztfGKp0ogujMmexh23sGE8o/ALjyYcLPDCBUdTqj4KCyRaX40ND8W0/x4aHkCppWozfH4bY+F"
    cB64 += "tqdAh1PwOp6M11nU5VT8Lqfgdz1RdBxO12NIdT+GdK/jSfU+nnSfE0j3P4XkgDNIDDybxABR/3NIbncB8UG67ngOiT3PIX7gmThHn0b0tJPpdNEx7HHDEZxw"
    cB64 += "3xFc9dIJPPDRSTz5+Znc8uzhDDu6N1UK+m67/zt23PMJTrjgc0b+sB43AFzIp8ugQTwz9gvOvusO5tbVcvVLTzO1bQmR446hVrGa43t4xsoE+LasUZaitlax"
    cB64 += "QlqZXLSwJC5H2pSSe/9+HBuHf0LdjOmUj/iM/Dkr6F3civr5i1nw/Cts/vYH5OvlKlytTH2CvzJRGIqrGNjg/dMibZuADHUSyyHlpZg2aw511fDkox9p4jUn"
    cB64 += "FG4FJoTv2Xh/oAiutmlcL4qnq6eYYwuFcH+9D64BeQqmPb0L7t2gvp7dDBmV/ZU8i6CMF1yDMpmr1J656lvwzg+pLcng6lnkOyF8N6xBjoCXRdyJUpawWd9o"
    cB64 += "s7LesLQWFte6rE6B27KI7gf04bS7j+Wixy6hPlTC6ad9wO7Hvs83k6vwLQvbjnLG9Tdw52tvUa2N+qc/eZNH5k7Av/ICGjt1kCVyqI55smyGiIvIpzicTZus"
    cB64 += "AoqIYvlRksZkErc1331P9U+TqE1VsEGuNOfrGfQMFZCreHLhi2+w/ptviNTUSK1blgSW+uIIxPyTHtbfLpcva+WQVAA9Z9EaPKsZV1zyrEDUCmOa42oAfzPx"
    cB64 += "wdXP2HmDPqJfXfkvhzHBFx9jTIaCArrTxRdYfRAT/eoS/IJlbCzPwgh8lii4ml+f8YzApG9uCAQuHAvSBlJikzSkGgzVNR5Lqz1mVLn8WCkqgx83wrj1htGi"
    cB64 += "MRvCjNkQY2x5iDlWFq2O2ZNdbzyRBXMbOOvgN7nujnHUxZMkQymGHXsYB59zFb6dx7IZs7j3qReoPe8IKvcdSjQdVfM2SRvJ6wpoLnm+oXUki9Z2LhHLJm6l"
    cB64 += "abRTVFVuou6jr6isX0s6Jrf60qt4z79KDy1aisR7xktvsfbNjzGlm8FPYTwvow9fupGi/qlOaXxbyGOzYtUmUgp2Tz/5UWpr8sS0EGTBPNxfO/+bEnTVKsuX"
    cB64 += "YjxdPT/963cBJlCQKFDUFlLZX589XckcW8r5vqcn3RtR8C3wGxnSeymc4F6pBqNrQCi1YUTos5ElwVG9pI+XMDiNFnHFZuXVhrXlsGiTy7RNMHGDxfhVNt8t"
    cB64 += "9/h2RYJvF4f4ZonFuHUWs7PaUXz6/jQox/bM4zM5/vjhJKp9TYoEx116AclINxSSsaxmI3ffdDdLu3eFkw6nIRLGdl2J4ajfLrYmZ1iULeC1DcUo8YLvhois"
    cB64 += "U5NJ4v48jcWjvySxY18a1a+KZ96g8aZ7GFjRQKusKAvvf4aFT72CU1aG76ljRmr5JzutrZFHqgQ/OB3BJMXq0jIa4jbnn/0CZZvy8K3meHY+vtyBieZiRQuw"
    cB64 += "tOIyuc0xBa0Ue7XFtG6P1a4Doc4dsbu3J9SnI+GB7QkP7kBsaBdyd+pMwc7tKNq1NcV7tqPlXm1pu1crOu3Tih4HtKb/ga3Y4ZAS9jm6BQcfW8zhJzTjmBPz"
    cB64 += "OPGUHM46KZeLTsrmqtMiXHcqXHtCnMuOrOD8gyo5Z+8aTtqphsP7VLJzywrahuqx4wmocbA3+fibZd3KDMlSaNrgUbfeo2Yd1K6zqdFzxRqP0pUuwbXMb09k"
    cB64 += "p+0wTgNjx63hgkteJe3H6NahGLfT9oqbYuQL2Gnl6p595nm+bSwn59zjiefmYbCkwjAQEVlo0UmerG6rUIxiK4TRTDCyynFRpDZB2Zvvs1kLiMjxh1JXvonK"
    cB64 += "V94hcefTdAobWrcoYv6t97P25TdIbi7HDUAsCiaiq0nu4WvOGbXzjzmtv6VZR7FOdZ3DprIU1131IetWRyks7klu+yHkd9yOZl360axbL3L6dCJPVNC3A0X9"
    cB64 += "O1K4XRuKBrWhWFSyfUuaD8ymRf8oLQZEaD0gRLe+cfr0TzBg+xQDBybZuVcNu/aoYvfulezaeTO7tV/LLq1XslOLZQzKX8CgrOlsF5rK4Mg8BoeXMsCax6DY"
    cB64 += "Eobmr2eXFlXs08Ph9GF53HBUIfefkMdzpxbw+rklvH1ZSz68vID7j7DpZsl0lTfgl8mybm7C04rTK0/hVYoq9K7CwdcVuVMqNWwiV9bPbtYR19az28DIr+ey"
    cB64 += "SLk8K+zRqf92eCaLkOUTMkaJWoePPhnBa4tmknfZOXgl7cj2XRLRJsBWWUPgzcOKrYrkPotDUX03hDGCiI9r4jROGc/c8SMpvvYK3N49SSxfSuWrb+LcKzfa"
    cB64 += "sS+5kWasvuJh6oZ/Tiopn6+axguBXLJRW2roH3JaW9Nq0G15IeJJj5+nruay859i8o8ziTctpqbiKxpXv0D90sepXng/1XPuJv7zAzT8dBd142+h+rtrqf30"
    cB64 += "cqo+uIjKd85n8+vnsemlK9j43GVseOJi1j50PvMfuIhpd57PTzeey/jrz+Xrm8/k0xtO58OrT+e9K87k9csu5OXLLuGZiy/j0fMv4p6LruLOi67hZsVC1512"
    cB64 += "BVeffiXnH38BJx98FsfscyaH7nIee253CTvvcD0HHvkc1z4wng9+2MD4DQ5flCZZYFIM2a0NkbSHqUhglTWCyKpowq7Us8hUJPUtiVWVEvmYSh8Ux/nJPPyo"
    cB64 += "jx/YdFnz8eNn4AhUbbr1JkyeQnqHHAEnbHny0B7fj57AG2NGE7niVBJtW5CflEXzhAMNhDjqF6IuFGqxU2RFyBHIIuJu+YWE/DA5S5cw+9EHiB1zAKETjyYk"
    cB64 += "F5pcO536B+6j8bVX6HDQAOqUmF5z2TM0akz8VBIXhyDPxj/osLam3YwZ9n3e+eBr7rn7caoq5tOmTSnt262nbZty2rSupXWreto0b6RVSQPNW9TTokUtrVrU"
    cB64 += "ZKh5qzQlLZI0b56iRfMkrVo2yeQ30bZFE+1aJWnb0qVdS5/2LQ2dWoXo2CabLm3z6dKukK7ti+jauZiuXVvQvUcrevRsR69eoj7t6dKtmA4dc2jTNkyr5j4t"
    cB64 += "CuIURsvJM8vwqidRsWgkc0a9wut3XcsVhx3PTcdexdjxixnXGOYrgciN+Ph1daI4Vk0dRkRVDVTViuqhuh4joloWryaOXy2LV+2AkyQIvn0aSLtJDWmY6hqX"
    cB64 += "mMkh3yCLZBETWPJ9SNguo6f+wJufjsC66HSaOnRV6OoT1qxVUcFJrDQotu6ybJt8WbQ8WTpbi4FsrZBtP4vsikqW3vcwoT7dyLv2arzcVtipRrKmz6LsijvJ"
    cB64 += "KV1Ph/12Zsnzr7HpoSfwtPNi5HXE9h9yWlvTqtHMDNmG8884nCkTXmPZsm9ZsXwcK5f/xMoVU1i+cjIrV/2sxcBUVq2ewerV0zO0StdVq6axZuUklq6Zyspl"
    cB64 += "UwjqrFoTlJ/JipVzWLbiF5auniYeM3Q/i8UrZrJk2TQWLZvK4l+vSxb9xMKF45SY/Za5835g7pwxzPllNIsXjmf5skmsWDGd5Wtms2r9LFZtmJXhN1fffvzp"
    cB64 += "A956805uuPYY9tqpI0ay/nLjldQO/wonFgPFN8QrQUCjTkCqrcfT1atvQAlArLp6fJFXX42prYG6FG79Rqx0JZZVjYIzBvTtREPKZfqs9XitsihWjFZouRTK"
    cB64 += "ZdnGJ1sLjrgm6OgZUxn5zViyzz0Wq30nwlrIeIJnTNY0ZXmklRZBFjEqKgyFxccgzBHoPWpsshO1bHjgWZoihtYP3kG8XXeckCFLcV/Dm++x+bEX6HvSAZC2"
    cB64 += "2XjzczSNn4yXjpNQG8EeMASQ5u9yWFvZSkbEsIAWtiEcsgiFbOzM1SKi+7AoEg4RUFjXcDhMhiIRrbqi5GlGT1tVx5UfrOPyNzdwyburuOjTlVz67Spu+nY9"
    cB64 += "D/ywjmenLOO1GQv47OcVfDttOeOnLVKidyGT585j+pzlzPplBfMWrGC+Uicvv/QeGidsDUpYbcfUZiwaITcni+KifLp0bsdOOw3ipJOPkfW9ha+/+YiFyybw"
    cB64 += "5pNXkjtnAmGnGjQEobom/GQCLylgxRuwRHZc4BLRVA8NsnACnXaGMH4CqpYSdWTNVLd1O5sddx7IrGnVxMvT3P/lS7jdepAjzs08aClLVmAsBfkWKQk7/Mex"
    cB64 += "fDd7LrGzjiPRpqWWAiEa5CujriM36Is/2NJ0SJRtIuSaENlWiFwrLJ4xva1n8xNPUltVSpvn7oTtdiOd04IgJsybM4d1F91FdnEOzfbfibXvfUnFK8OJVFRj"
    cB64 += "q20jy8nf6bD+Tu38WTOu1IOi3JcnbWLEL2HefOJjPnzyXUY89Dqf3fMqI+57hXfueplXb32DV258j2dve53Hbn+DB+//lHsf/oHHH1nFPSOSvLk8RPueHcmO"
    cB64 += "FbJ+YzUhDUBmZP6stS0Pwh5GlsRSjwMgCoc0Kwpz2ikH8NQTt5AvnISqarGbBJxEEpMIwNaEF2/EjzdhNTVBQCl9D/mYtoUUtpGhKJtK2jSKt8MJJx+CiXg8"
    cB64 += "eNeP7LVjG9oO7MPVn39EuGsPsjTJSiREJyVqCzF4slZVxuGLT79goQY+cuqx+LECslLIpfpooYml8gEZdSEkSxjWSjOKRZYdEtiiFAgoLZoa2PDISzTKdbd4"
    cB64 += "6BYKDjySnKwi3FxDs4Za6u96jsScufQ+dl9q5y9lw6Nvk1y7lpRJ4cui8nc4pPK/Qyv/TxMeLqUJi582gbtyHmbpQuIL59OwZDnVSzdTvrySTRtrKY+naQiF"
    cB64 += "sbQSK+ranW4De7P9Dn3pNayY7oNak27yscMWH33+HSedepxacRXJIDK6/9PT14Mr8jLka4AtlbJdm2QowiKtwNzyCMkFFSS9JGGlNEzK4LsiDaivfBSFuVjt"
    cB64 += "m2MP6Ex4aHfC7WI0rZpKqH4Znu3QsXMbLrnqMN5/Y6Vc+Aquv3kQkVSYnO5tOefDD/FLmpMVClGkze6O4pmvpLDwyDq/gddee57q9t0IK5hvDEfJ0u6Dkaia"
    cB64 += "E1gSPRgkYwzGMriBFbJsYnoZtXMh0ow2rkfZfY/hpBNELj+N7JO1FVfSlmhRIbnNbOwRX1D60Ui6nncSlvrR8OpXpJet+fcFmXQmxTl8M3sd6RYdSC2arlUX"
    cB64 += "skK5ZO92FVlHPkLkxKcIn/YU5qwHSV1wN7HzL2bgxadw4GUHcuLFu1PW1J23H1rPbm0KcBNpxX8b6du9PQRmSjPd8OeHb/RGo2ZMSobOl3INusPXrsAirRDf"
    cB64 += "n+FRMaUU05AiHMrGb9GMUI92ZA3uTXTX7cjaYyix3QZhbd8dV3uSrqxRdO0cgXIkvuWSl13IK/YgFSIAABAASURBVK/dyPz5Zdx+6zdcftlgenUrwdgWEROj"
    cB64 += "Wb9eHPvWa9TGcrXaNOSq9c52hGwpI43N4vpK3n78IUJHH4Q9ZEfSAiICu+s6WI6H8CbD78qFemSpfL3AZBVmE8vPo6CgkKxmBbSIuNQ//DJWcRH+WceTc9JJ"
    cB64 += "uF16UtiuPfld29J84TJW3vEYLY7eB7t/N+o+GSeLtgY1pimvycTvd1i/H+v/ibOPayw+Xy2XVLFZSc9NBCDws1pCVhcS6RIa41nU1YaoUFJ0/TqHOWthzMYQ"
    cB64 += "X5ZGGLMgyYdPjMPbvIGDd2zN56MXsPOQvgSuEAHpv2tVOABPlopsUlYIX4ViGqgFCYeLPl7P6p8dvHmlEIvgFuTh5mbjCLCplEOqPk68qpqmqiqSlQZ7UwOh"
    cB64 += "JT9RN+lNLLcMQm24TfuZJtvm3FNeoHevbG64ek9CJoTwoNPGtm2677kX+99/B14oi5byhVr80sLYZHsejjFMWrmQiYqbcs85Frd1R3UlrMkoDASmDHBtgx8E"
    cB64 += "wAKuLete6bvYbZtj2rck0rYd+bL24SzY8MobZLdrTc4JR2D22wO/b2+ivXoS2b4nrfIjLL/5fgoGdadg8ADiI6fSVFOjdqSR39F1WpL/73oGccDiijjzUnk4"
    cB64 += "v8wl5IY1GJqfzQeQcHMIYmkaJZISnX5lWGCKUKn9w2krLMYss/nwo1mkNy1ip0G1WFk+I74ey3HHDgPj8D/pybdS+i4rJVcTUQbeweWnKodT36pi6k8x0tNW"
    cB64 += "glyjIzCQ8rBrkng1iseC5GxpHWZDI9b6NJHSTUSWjSb18yvYiY1YkWJuuucseg3syIlHvERezObtd04iO6rmBBx+PYwxuJbN0AvOp8vxxxMVGoq0BdRB2m8m"
    cB64 += "sFi+FqoS/pPPP6K8OIuCs5XaiBZo8C3SIX0U4KPKkUWsMDG508JwDg2NSU2IZoQ7dsaInM7dye3YjkLboWzCz7iy7HmnHkldnx747duinBKxzi1pleOz6p5n"
    cB64 += "yOrRnlj/TjR8O1kWvFGT9Fdhf4eLuvk7cP0LLH3f8MOyGnq2b0b1tKV4fiG2V4Ap2U7jnKMZ7GGnfEzcDzQP2k+k3MZZZ2ha3siy7yfgemvY4/D2vPFLBW2L"
    cB64 += "ssnLjWAIY/zQry2r7q93wcUzYdAr33fYoJIvzmvi1NfqWTQmRWjqMtIaPE/W1bgQkO/4mEaBtikNTSn8JpdotUC15B2a5r0DyqaHC4u55MFrGLJDJ8455glC"
    cB64 += "NGkCXEinTrmIFX9++IQsD9tE2fvR+0h360qOZSiRI2yjFUiOJ+ll0ZYnqhj1yAuED90bs8t2WLK6MVtDJAtra5VMfi5ecQF2qxJadOnCrPVrCPXvSXiHgVg7"
    cB64 += "91esOIj8nXaV7lK4m6rw2jYnMnQACi/VLxerEQrsHApWrmTDS28T69iW/IJs6n6cqUnm/rnI2/BJPdiG3P4HVjIS+uLie2nSns/GhiQFy1biVaSk5lzcrGJo"
    cB64 += "3hqNhMr5AotIfTZpI4XpdZ0HDT6h1esFtCXk5aTI220gL4+Yw6mH74LGCxO4SmOEJYNn0qg1gdHHlaVAgXGdg6xXnPsm1PPQW/Ws/bIMb8l6HPlS4wmERgAN"
    cB64 += "6gV8tIqzJKeEIeSkiNUsJ7n0LZwN32KToqjjTtz8zO00y0lyysHPkh1JM3LUpWw/qH0GGJig5p9S8MJC4hEpKmLYAw/jRaIacEMbCV9kgm8+YUk/cfJEVm8q"
    cB64 += "pfics0gVFRDu0Jnsrr0IDehDzo4C0a470WzPXWk1bBeK2ndiQ2MTyIKFW7WBkhbY2ituVlBA7U/TsRs9Il26kmxoIrl+Nc6ataJSIk4T1a++SeXnX2FrMcOm"
    cB64 += "ClJr1iGlkZQMwURzApHZNoe1bdj8ZS6W72P0z5NFWbp6I9u1y2fl94GrLMRYEWItOmPl5EAMTJaNl+3iZ8nFxdKYmEtKy3E76tE0f7YGPUG7fQfz+SqHHAXf"
    cB64 += "u+0wAHxbwFRdHLmYFJZckUWctJJZlQ1x1tRVM311PS++XMnrdyygdMxajPJhLpYqRcFK6M6RhFFdDVpsCgRZZKU2YTaOILnmGbnxJXixPnTb+1wuvPcaxn0y"
    cB64 += "gXsuepVB2+Xx3Zg7GNCvC5YxBIclKAbXPyWDhW/52FphdtlnD5offQRFfi5tHUMnvctSHwIJKt0EY995i+g+O+Mesy9ZA/pjawGS3asroXZtsJsV4Gh16tQ3"
    cB64 += "0je/hAVff0d66Sqc+YtJzf6F9IwZGGX+wzNnU79qGaGVFZjOHfC01eSsXiewbcBdu4lmyv8tffgJzJKV5LZuRs2kmVpNpwgJZK5tsH3DtjqsbcXoL/GRevFl"
    cB64 += "HRwJvmZjBT3z85k3UQNo5eErOWt6diHZIgKtXa3ewGsdxmuh7rYU4FoauQeP/OwGKfMX/LCPOWB/Zs7czCmDNXPtMGk82RdIutCYgOq6EJuqLZZs9Bg3PcXV"
    cB64 += "d1Zy+AmzGP7OWrzyNOHAfwRIknv1M/YjKtXmg1+IpcEOJdYR2vgR6RWP4dXOxITb0mWnEzn1jlvYaY8+PH/zI0wdNZ1LL9mbUaOvp3OHfIz56wZFnhEvO8Iu"
    cB64 += "d9+OJ5C08iO0lbVtJ2Bqsatp4jJt9Cjq6yrIVeK4sSFJXLk6Khsy4EgvXUN63hKcuYvw5y8kd90aasZ8j/PjDzjjx+OMHUfqm9FExo2n6tnXSaxeidEKvDGR"
    cB64 += "wFtXir+5nFR1FX4qQevyKua9/DLpslKyV2yice58QtpxSBowns+2Ov4uIBO28I1PMp0mPz/G9yOX4njNcbMNfk42Wdt3IdzeUNA2RWFbl6LA8rcV5tp68gQe"
    cB64 += "vdp5FNYtJVRThtW5C+UlXSheOJn9DtiVDWWVlFY1UNrQyKraRmavT/DqN+s595b57HvsHM66ah2jxieU/9LSPpwnK9Ucz24Gyo8ZE9KMDRGVPmPeRsJN3+Nt"
    cB64 += "fBd35bty5TOxou3otOMJHH/97ex12C5M+eJD3rnncdpm5/Dx8Et54LGjicRCGMvNjIcxGp3M3X/9CXRgqR2VxtJDTodOFJ15OJZWivmycu0sQ64WJVFNxtKG"
    cB64 += "GhZ+NYpY797U1NYQXbyS9OIVOAoxnCVLcJctIblqJan1a2WRmtg0baKs2FzSc+aTnLeAxOLFcu/KO372JfXla0h+OUZpjijx+lqSiUYaSVAmmdd6KeZN/pG6"
    cB64 += "6b8Qq6ih8dPRiiw8IpJTYvzXTmzlG2sr6/3V1SSv7IyKKzBbs24tPbt05tOv1kIsqsHOJq9VS3pow7t/C4uBLaIMbm6zfUvYvpXFYNHQ1jZDmkPdjImyhmGy"
    cB64 += "e+xE9zyf9+49SVYrwthJ63j5lSWcd/4c9tl/Dgccspjb7m7i+0kF1KSbk5alDOIf3yrG2K0xYUsD62CkZKxNilum4W34jNSqd0mVjcF31mIVt6Fg6Onsevwt"
    cB64 += "dO09gPEjPuLN25+AirU88cgJTJp2Ewcc1J2wZWPJGmqq8NcemmuZop4x9L3gQqqVHI0Km0UKhIr1TmqSVbaYO2aMQJ6P26sL7qr1xDesJV66kURFBem6WtyG"
    cB64 += "BrxEnIjxqK+vIS3yteeabqwnmYxTp1iypqGcCoEuWb6Z2KpSEhZskt1fJ8u52k2z3KSoVCpn1tix+NqPjcxehFdaSiCj0UIkI+g2+FGz24DLX2Ah/WEEM18U"
    cB64 += "b4qzqdJj1mojC1aCH8uj105t6N08Sb/CFF3zoKNyPW0Ui7VRMN0y5FOoel5tHTXzVuCabJxEc2beOIr9+z7Ifru9zLmnT+OhxzYzblqI0sbmNMWKSeXFSOfZ"
    cB64 += "WlCE8cMxgcomHKklbJYRii/GVP6Iveo9Yks+gA3jcJJrVE4rsbwjyCu+ipLik4jUNjHxoyf44d1HaBct5blnj2XGzMe4+OJ9yVMW1ZIVtAhhaUSM0gv8lYeM"
    cB64 += "GBid0nxuxy6UHHEgYQ+y9KFIsZk+EeB/7qxZOFW15O08mGStAFVfB42NeKmkvIBDsPfZKLDElayt07XBc0l4DsF9BQ7lAkmT9lQXTJmM3bq5JlAFTVp4rXWS"
    cB64 += "rFGSt1TpnBqV8awwq1cupWrdKnI0PpWjJyhs8JE4bKtDXd1WrP5nPp7cQEMqTkmzVnz7YxledkfIaU4oP4d+O3TBNNiUrYiz4OdKJnyzgW8+rOCz1ysZ/moN"
    cB64 += "775ewegPZxJqTOFGS5Q38+UaptCUXEu4uU9hnyhFQ1vRamgRrQaHaT4gQovOWRQV+uTZ9USaSmHTKtIrZpBa8g2pFV9il07Gi28gHgnhRVsRpgW+Y5OuW0Jj"
    cB64 += "+avUrn+ItrHZXHfZ9kz7+SEmTX6I887djbwcB1soCEBljG7Y+sNT7OeFLHqcfbbkyCYiVs1MmBzFQgHrsspKyubNIbdbZ1w7JDfm4Mj6xP00dbJGNQLWZsuj"
    cB64 += "XkCpx2Kjm0KaZZNxKRVKSwX+emDtqhWgdtKqqzUGm32HzcajVt8dtWebEE36Nmf+L/iyeAT/RVQyQcr8bf1T0384rT/c/V43gb/EZv3mOloox/PJ1xuxGhL4"
    cB64 += "8TKUfeXbT9fy1jOzGfX+MqZ/s5HVUxuoWFJGw9pKGmS6w1RT/csUHCnOKmiPU7pBts3gW1lkhT0uueVI9juqI3VrZlI9YzbVk3+ifLKC3tnTaVg8n/TaFfjV"
    cB64 += "m5V7s8jLbo1lkuJVipXtKU7JI5y9li5d1nHovmFuuKoHn7x3IYvmvcKPPz/GnfecRr8BbQjJohpCoAHxlaX3t8EA2IHmjU+LAUMxA3oJ6D45moz5QTpDPUzK"
    cB64 += "6qyfMgW/1pF1jlIlS7VZ416OT4WAWJ15dmlQeqZB8qzxE2w0ApBAVCEAVmKoV9lUOklFeZm8gIejNusVbMVlOS2NS47KoDarVX9xXRWNG9eR/nk6vlxyROXY"
    cB64 += "Roea3Uac/ic2UqQnpSWaYMnqOhZMFUhq1mCqN+A3NlA6rwFXWzWmsg5TU4lVW0qouhZTV0OkpoZsax2pzYvFwSaa0wLjbQBTRMgtoXZdDV+//AE92hbRUzPe"
    cB64 += "K01jVdkQNyIXTXh8Ldl0JyWHSFFMm/47kw6HiCgtn3vp+Rx5z9WMHfc0H399O3c8eBKHHz2E9h3ziUUsbP2zvDBWxh3aIMX7sgK+LAh/w6HxxZOItm/wZMI6"
    cB64 += "HXE4jgBs45NjrMzfhQUyr9BqzyqtIK5kc6XAUykrVilwVXkegaurkcurljxN4lXmugIieu9Tp++NohrJmPKMFkZl4gxiDTjEsMgWSTkkcWkUbXLi1DkJYpUC"
    cB64 += "2+KF0nMgpYpvg9PaBjz+f1k0auO5MC/EO+8ozqhXxBDfJEvWCG4cEg0ChOZcog4vKXLq8NPVeE611NCIX7cKFcaSW/NDDvnZqzjwgJYgU++YXOaM/4mpn3/J"
    cB64 += "/ocMJtYsjaeNZT/tiLcrHYo0q32RmJOOS6HxHApbddU+5DIax3xHecfOvPjhSCnVYPshjAhjdIosg3Al+k3hlr4HZPhbjqC2OIuXIR1y6bD3MBojUcnukUXw"
    cB64 += "RV0WgFasWa2JWEM4GqHWcwQeN0O16k/Yh5N2AAAQAElEQVStvteLagSfRlm2OolYL0A1CLj14pEQyBr0zVEH1tdUZcS1XJ8cyyYqtKkKCQmSIDABPnGBuB6w"
    cB64 += "Bdby2XPwxFuP2+S0tgmXv8DEV6fXlVaRlZvLl8OXCzwVsjDqjp/Ed0XpWrQLLWrApAW2VL3K6LtAV9C8keqFc6QyWyu+njj+Ro4+pC3PPXME+c2kHCufkBNi"
    cB64 += "3LvDKVsxnwPO2F2ASGAp4IW0pPqVpEDjpzBSYPX6JM3b7oSVU4Q7aQzzvp+BM2hPPv58DLbciKOBQTKr8u962r5QYcDSZGnetwep5s3RG2ICeEjBk4dFacVm"
    cB64 += "UpXlRCW3ph41AkS18anG1/0WqhMYGn2o1bcaxWP1lpexTHGVicvKBdeKeCOugIX6ZURpATCB5jY+KV0d1Q+eG7QgaJCla1i+jiD21KdtclrbhMtfYJKWMlcr"
    cB64 += "aP/8m5WsX79OY9+I5TWgOYwrS2aceraATNe0rFu6QeBrwNbVDZdqJViqTHuRQNEaU7+Ik0/Yg04dmvHgg/spSkpIta3x0jYfPPk4bdrZdB3UBmNSMgV/SnI+"
    cB64 += "AplFAuMYVi9soPOuR5MKxWkQQKesj7MhnMOS5atxpXgTTPO/0Kdt8cmoHQyEXQuyc2i9646kBTDUI0sfXIGsMdmIU1mhDYkEdXr/B4AZn2o91whg9QJIALK4"
    cB64 += "hAosU1LXtOoH14TuE/g0aNIF34L3wXgEZRvEI65vSZV1RMF9ANQqk8bdELhXzTjV3xantS2Y/DkPT6K7mg96K7O+qSHNuPoIr701DddqxBKwfLk0+URQHOA7"
    cB64 += "TQTu0Pi6ug1614CVasCOpklXKkCXMu28blgagN5t0+yw4xBcxS9nnrEDhx7YBex8PKuEZE0DHzzxCAcfM4RQzFU7tvh6GAXQQjO+wO6RlGwJnITPpuVJ2m+3"
    cB64 += "G4n6jcx66nXW5vTmu1mzcVMOXlBH7aqwOvF7nUaMfYIBML5NqyFDMFYYCazJ40t/Pgm5fSeVlj5cmgSoBlmgBuk0cJMN+CQFsLjAklAUH4AnrW++YjZXkyQt"
    cB64 += "+ZMiaVSrR1dlFfjLIjaqfErvG2Xx4romRGnxcoB641EpHSWaNOHFS6+2yRn0cZsw+iMTo1tLyvMI/PpEWYmvF8CiGXOQyVGXkuqSL12qWxmwab55cXxPV7lQ"
    cB64 += "REYUK3S1YlyrLkcI5fbET63i9FN2JBxSpCypLTvM488eT/MWque1VZvNqVqxmglfvMvuB28PUrzRDPb9tL45CGO4at2TlQv5cerWVZMV6UZe87Y0zpvO1x+N"
    cB64 += "xhu4HyO/HiUXosH2TUZOVf5dzi3wAl9y6peWvXoREtjCxhAOWjYgHAj00mPKlR58EgJaAKyUOpOUVI7AFGgzJR6OrFHSgCNwZNyf7pukpzo9p8QvrqurmKxR"
    cB64 += "OnBVX1pTrg2Sxiet76i/QbkqlavRWBiVURPb5JQY24TPnzAxBAq0tWXRIKi9Ny1O2eR1uPXVhOUaPXXKiNDgGy27M5GBOuWLyIAuias0g+VV4mkRYMVaYofz"
    cB64 += "yXJnc/wJB2BptllSqOXatG9vePjRwwmHfTDtcL1s5kz4lrS3nqK2oYxFIFCWcfT9VwpUKpDZCpKXTFtHx167YllRNnz6Gm//uJF4xz4sWrpSpQxeICfBoREL"
    cB64 += "Lr8XCViF7Vojp46tvgUUACFX70PxJtICVxMemoqySD7aXhSYkIzI4m2htERMqnzCWCQsqLMM5UrUZuqoH40q2aRrAK4AoAFQgzrBFHQFMGlQJQxl6mN9NAaW"
    cB64 += "rbttc0qcbcPoj1wkroDg2BFWVyu7vzRFcsY0WbWge0iF3p9bMb8Ri6QopQmdwMiKRew0TeUrsTSrTF4fga2BvYfm0rKkBa4UZQTjAKiWF+K4Y7fj2BNKsKyQ"
    cB64 += "eHcAN8Kkz99k6ODOKPsgHr5IAPuTIQm2bnxZgZC0vHRBGZ0HH4ZVl2DJq88xsqyIWYpJ6poSOF4w7J5k4nc9jDHYBbnYkTB2oD6kCvUmT0AJaZsoLT006Tkp"
    cB64 += "Sulb0BtHwHD07Og5rTpoFSlvmgFYleBS5qVJiC/GwhhIGZ/AVSZ1n8ZktJHWBAwA5ujZF3kquEnvApD5/+wg8/E0QDB2ViXpchnjtfMI3EJaSjP65uMKJoG6"
    cB64 += "AlCldK8y6Krg3BdZWnWm4xXSdC4mtyskVnDGqbJimueBIjIWxkphvChhAfqeew6npIXspiW3abXEj1cx9YfhdBvQRUNgaeB88dKtFBi4AR+LgE8gS7LGUF1m"
    cB64 += "Y+d2Jz1/FuM+/pKNLfsyatIclHmhPu5Qm/iVkmlqf6UGxUtxx1Xc5Gnj3yeleMeRiWlSG0kBOFjBxWWBlCuVmyPonYbeV18lx/9zSjoBLCYdebK+RmV8PAsK"
    cB64 += "PRu3vAYn7RKAw9EXT+SLPOnQxcPJtOHqyZAQ3wpNjCoxTGZ0bamEIRYASO8a5VYDYKVUzsuA1MqALSXgeXrXqDardY21aA4CJ/+rw8eXx9C6Cs94GLX3W3Wx"
    cB64 += "/e12W10NlueTlqke/lMV6YWLpaQEXqA1qRnUuoRA3fPlHn3NON8TwESZd7JkTlppDM9gxzphmzyKs5ez5z47YFQvpBlr6ZvvR3DCBk+xWcfWJTzz5DFEbAHN"
    cB64 += "745vOlBVsZSGujnklGST+U/0NfiB61TrGA0EWkU5loZM7VesKaOgVX98N4fqTz7g4xc+Z+3mBF98/TNffTeTr7+fybeiMeNnMXbCPMb9tJDvpyxiwrSVTJy5"
    cB64 += "jilzNzNzcS3zV9WyeEM9G8sSLKtJs17LvlHl9dw1cgHry8oFBEAD+qcDgA69wiiV4WuQkIDSRkaHha5PdP1m6gXoKvW13jbUy9TV2x4NtruFwh5NwbNxqXTT"
    cB64 += "BCDJAMzXQEvngdXOVgOBlQtSHAHIgjjME8jSAal9RwIZlalW/SY9N+/WRarykXb/IoGn0r+RrzohxCpDiLc+Zs5tDrJANF+x1tRVSRasipFc/rMal9sJBhmf"
    cB64 += "4EQKCMjoYQu56owLGvCAPLcayy+RdekJqVqOPqwHWTGLAGRg9E8dCnojdrasntHgHHJkP446pRnBbrPxt1P814LNS36kID9FKKIUp4/sl4WR4pG98FF4LZfg"
    cB64 += "2yHApqrcIrvtjtDksejVt7n93Ls576RbOO34Wzn1mNs56ejbOf7wOzjusLs57uCHOGm/Jzl87yc5aO/nOWDY6wzb8wuGnTiay+5bwqGX/sxxD8zlop82c/XL"
    cB64 += "6+jbPIu2LdQfX03p/BP962nLaQkFGeun0U7oVUTSdlTBxkiahS2yiEYKiEbziUULMpQTKyQvoHAB+aE8QtEsnKxsnOxsQmGbiOejKZTRVZb6GddTgxK6gUUM"
    cB64 += "3GXKQAAuV2OAjojarRPIGiI27QcNxMm8VyFx4P8hX89/SsF3X/IGQ2wr3jWeeFv6Ycthbbls29+0DPSIqbWEKxpwatZnmPv6DYQQkjTQrsjR7RYyApeRJTPB"
    cB64 += "YkDdC8TzTTFkdxFYZnHeGfsLBgEoyHQvSC0ZAdmW0jbVW8xan2LO2jinXnwM+R3BalOM6TAEu313qqmgePtWFG9XTNshJXTfuQX9dm/JoL1bs8t+bdn7oHYc"
    cB64 += "eFgnDj2oGyecMYzTLj+OK646hRuvO4fbb72MO269hDvuuIRb776a2++7hjvuv5Ib7r6Yk24+hwMvP41dLziJnS46gj1v2INjLtqNNbOWsLnOY1NBF2Z+NIdH"
    cB64 += "d8vn2KFtiErykAYymBv8N0eQOknKwjYKHEljk6NBKoqU4N9yJcd/P4r7Jv/AvdP+SPdM/YGA7v95Ag9OnsATomcn/sjr2gE5+eSzyLciBK7L+D5Zsv6NiuuC"
    cB64 += "lWZCMqTUvoMvC+8jp0CQ3omGY2yQy28skJ5696dBLro+6ZIhhQv1SWfLvd41BM8BZd7pfcqlUffxVJxqDc7mJp+GZFJ8g5HUeKi9bXoGSqzS3uF3s6tJr9HO"
    cB64 += "vsw4UnBAhuDwMeqwwdNbL8C/KLgG5MuCeXqfQzinHb5irj5d4/Tu0QV8W2oJ5oQPgTVSpr9Uwfo7c9Zz46Qyrp1Uy8OLmxhy30Uc8NRpHPPs1Zzx6uNc8trN"
    cB64 += "XPL4cdz+znk88N55PPreuTz//pm8+f5pvP3embz19lm8+u5pvPTK4Tx20zCefvAc7rvvbG678ySuu+U40VFcf+Oh3Hj9/tx47TDRztx502Bevn0I7z+wA2/c"
    cB64 += "3Y8z9/FIa1P+3VvepMopId1mMOHxP/LmaR05aFgxMS+mPhtR0P//npL1tSiko0699EXdwlm0ueAMis84i1DvHhT060NRr76UBNS7L0V9+lIgatavP0XbbU+W"
    cB64 += "qMV2A+i8fT/yC5oRs8IZ9xwSrwgWQazYEABYz45EcGQl09K0JwAG7hPFYJssi5OuuoGc1i2pVYC2rtJjdYXD6kqXVZUO60SbqxzW1Lhs0rsNel5T67JOzwkB"
    cB64 += "1DMhfl6d4srbRpAUCD1fPREFo6Ymt81pjFHHPKaubKCuIpfG0o1SbGuM3VnUDRPqomt7iIjCHbCinbGyu0Feb8jvi8ntq/v+ULADbskB4G3muCN7E9JKVaZM"
    cB64 += "6jHiF5BPvXJg6zZtonbOKhbd/xZL7nyWBXc8z5yb72XqTTfy/RWX8fnZV/LW8Vfw7BEXcO++53HN7hdw3s4XcdxQAXH7i9hjwMXsOOByduhzPdv3vY1+A+6m"
    cB64 += "74CH6DnwUfps/xwDdnyd7XYbzqD9vmGHo6ayxxnLOfimOk5/0+LBebA07tMyN8Sp+/Rj5Pvn8MzzZ5DfvQv26u954aaeHLJ3VyLB5AhL2QY0rv+joqsry2hU"
    cB64 += "4rU8KBeJsMe1l9Dl5isxmqQrK32OuWUTe164kT3OWcdu56xh13PXs9tlGxh23Ub2fbKUM8aXMqsxSWCZGpscJWAdWSrIwtfCB2olR73ClLSeHc1Th6Ahm6QA"
    cB64 += "6BhDlUAy4IjjOfqqC1lc4XLQCfMZvOcvDB06ih23e5+d+7/N0AHPs/3Apxgq3QwZ/Bo7bPcxO+08iSuvXqwJYli8sYkbb3uDqy/el5K8CJaAG3TYCn62FQVm"
    cB64 += "15XwX0ysxl24HDu9Wg3FMWaDaD3G2oAV2ogV3qCgvlQg24gdLRVtUkxRQSirjnBM5bNyCbn5ZIXWcvLJ++JL0TJrBPwD5cQ15RcrIJ46vZ7Hr/uOTSvqqKwK"
    cB64 += "U1kbobIxm5p4M2qcVlRZnanM6kl99nYk8nagqdlONLbYlYZWw2hofQAN7Q6gseP+NHTbl4Zee9DQf1fqt9uJusFDqd9hIGZITwqGdKTVwBa071lA8w5R7FyX"
    cB64 += "0spGPp5Yy2mfl/LwnM1UyXWHI/WcenQRtx0d5vErO3PY3l2UXA20EZF6XZFGVr//7anZvnnVBpKWRWk4zN7nX8mw2+8jlZNkaXmKE2+vZsIvYTZURaiKx6hP"
    cB64 += "hEmnItjxKHYKNlZbTKwuZmXawidEfWOCBunM1VOObZFQrFUrTNXp2ZEALh4JueOQ2m3QQiKbbEyvbtz60jNUxuHSCxdTWQ/dezXSersU2bvkC2mSNgAAEABJ"
    cB64 += "REFUENmnLdkHtCd8VDdyj+pBwa4tiTseRTk2t9/VUzpPcP7Vb3PtmXsxsFsBhj9C6493/O1HAILq6kYWjhlBy9QX9O2+lt691tG/R4LteqYY2CNJ/25xURN9"
    cB64 += "O9fTu1M9vTrUMqBdDf1aVdCnVSn9Wm9kaKt5DGn7Jecc14ZmJUV4xgfNQl/mPq4AefWmOjasS3DDxT+Skomzmu+BaXEwtDoMv82h+O0Owu9wEF7Xg3B7HESi"
    cB64 += "7wE0DDiQxu0OonF70eCDaBiyH/U77U/dzvtRt6to9/2p3Wtfavfdm7qD9yRx1C40O2kI253Zj30u6Mfhl/Ti3Ms6cdslLXn6wiJGnN2c149tR4vsCB8tadQK"
    cB64 += "LxvbinHKYS3JjbjYJgwmih+YL1/3Ujv/zRHozFOfqpYtoS4UY+czzuH6B+4iD49ZC8IccnWCtQLCZXcXcNPDxdz2UAl3PNKK2x8r4pYHi7n9zpbs07sed3Yd"
    cB64 += "saq0hjZNRaqeJoHMVnvZGuF6HDYZT8AzpPUuCPj1mmAz3ZVe0y1KuP/ttwnl5HLTTVNYOGc5d93fmhte34vBzxyDf8eR1N9wCLVXHUPjRUfinnIAmzXRIrEa"
    cB64 += "7n+gK61aprj4ync4cp/enLBfN0Lqu7EMxmwhS21u07OoIIeJH1/FvLlPMGvGN/wy63Nmzv2I6XM+yNAMXWfMfp8Zs99j5ux3mT7rLabMeJ2pv7zGtDmv8PMv"
    cB64 += "zzNx2sNMmHQ2D9x/hAROYHw/MwcdKX7luk2UVsU5/5S3SXlLoGV/nFgxnhUS2aIwjgbXUeDrGxtfHQ06aPkWllyGrQSupVgPkwMmSxQVhTGWhYoLF56sKrSM"
    cB64 += "2LSS28qN5JATi1CU5VCS5VEc9mgW8ikMp+gXglO7NuOk3sUsq7MolSWJRUM0mhj1KQ9PW1i+LIbB578ewTsXDQOeFj2rFs5n11NO4bbHH8MW3xHjajnhnJ8p"
    cB64 += "lRXqJgs5Q4ui8Q0u4xo9fmiEGbUWi5sMaxPql+69RRaJWkiYELUKvB3PIlhh2r4h2Egv1+JKW7Y4ajFwl8aDGlvth7K54olHade3F8+/vJThX67nnJvb0bZv"
    cB64 += "C0aXpflmpUd1TQyr0uBoQROuBP/Jb2HmRq67bgf23LeYO24eR8dOzbjpwj3VZghXAEe6/q3P1m832+JqjCFsB2QTxsbYPkYJQEtKNgEJLJrakhIBBw26r3jB"
    cB64 += "J/Nd31RU78A2FjbZhGwbS2AwSva4qr9cmfjaepuzj3qVGrmIaM5QbLsNVgYgUp9SGZbmqo2LbdR2wBMdlt6IPJULKPjDQ8uksS0H23Yw2mHwwy5G5Os5FHVo"
    cB64 += "U5Cie3GCdsUuzZsZYllQa2CVZ5iX8pnaaDNRgz6tIc3yBo97R6zn2Ql1GA1qs+b5rK1qxHJDGALJPQnx/5zG6JuH6zWxSZPGGrwH5z31JH7Y4vnXFnLuyd+z"
    cB64 += "OT+brANaMbvMZ9wim8/me7w3z+Et0YvLXD7Qinp4mcPqpI+7ooq4YqmUdBVYskZxz1Ibjp6rCBHEY8FuiZyBgAZJ4+P52Rx0/iXsc9QRfPH1eu6/dyp77VPA"
    cB64 += "zscO4NPVTXy6KEWTXHRocxKnyhAqUx8+/omGbydyyJGtuejiHXn42UmUVa/k6duOJ2qHIRQh7FuoeX479PTb7T/r1Sdtp1irBGd9Q4hzTnyLDWUxrLaDMd0G"
    cB64 += "UtirFa0HtqHTjl3osVsneu/RkT7D2jJgr5YMGVbCLsOasc8+uRx+UIzjD7Y59SCPsw9xOf8wj4sOTHHFASmu3z/NrXuluX0nl3uGehxWUsX6uiY+Kw3x/OIU"
    cB64 += "N89s5NzZSU6ZneD4uWmOn5fmgnkp7lju89IG+LrUZ9QI+Phzh7gXJhpTIN2UxrPCmhpGwPuvujVKVzhumDWbqhnx1U+ceu2lJAWG2+4azQ23TMTr2Z7onoOo"
    cB64 += "SYBdZhGuieLXRUk3RoknotQ0RJhbE2JilUutY/CqN2El42gtQq3rYmuCZYdsUpKgURQHAgsmaOEbl6Sx6a1w4Zr7b2HK/GquvnQaJS0ruOTe/Ri10GP4TEND"
    cB64 += "ZRamMqVdB1Xe6JEzZRXJ4Z/RvnOIp54+jrdHzGDK6Jm89dy55MnCq9R/e/7Tg0y6Yl2Fz4r1dZx18gesWLJZVmozVsMMzOaROGs/xl32Fs78V0jNepnU9Jdx"
    cB64 += "f34Dd8q7eJPfw530AckfR9A04XMaxn5G7fcjqB0t+kY08lNqv/6Suq+/ovbLkTSM+o7drCTXDGpJOw3EWoF6TTzChnQOlQq0GzW46cYQ6aYIm9xs5jfY/FDh"
    cB64 += "8INmvb1kNWZFmWAiFya3kpuVBYq1Mlo3md8/+0krx7dUwf7XIxdzxpkHEW9o5PQLRvDy479gd+9PeuhgkjUW0Q0WqVq1We/h1ytg+JWsWllHte8nDGFPVrNp"
    cB64 += "LXhJgcfQJFcdU2uBu0ziUqeUUdJYODIvaVm3OjtGVqcBPPH+C6yRlTznzOHUpmdx8VPHMGaVzcejfZIVEWLrbVmvEFSFyF23maaP36eZrP3zb17G6BmlvPTs"
    cB64 += "V7yhFXXL3HyMUdihNv+70/rvXv5zvPPlSjw2lVUx8eelnH/m+6xeUUosx8OOxTBK/FG5gcaNpVSu2sTmZaWULt7M2jmlrJyxksXa9pn74yJmfj+faaNmMvGT"
    cB64 += "yYz9cCLfvTeRr98az6evTuCDl0bz+rM/8sKTU3j63o959PY3GfnlVLIdyGtyod7gKb6hAeyaCL5yR+kEpGUuTI1HqsFQkchibmmKRM1GcptKiQqc85dVKbVh"
    cB64 += "sWVYwSc4xC+4GA9XM2fOos18/9NMTj1nD8o3pTjmxHf46rPFeH13J91tJxxZLk+xllMDRpPMrzb41TZUhzDBtc5gK2TwqiGp/VXHqRTfOHUCWEqUJ0tlPJct"
    cB64 += "+TFPQYRIbqxR75tymnPXy0/g5RZx9jnvsW75Wg4+ey+Wx9vx6hcN1FXmYJUa0lpIOIrFYutqSX35AVZjGVfdewZVinfvuO89XnjsdHp3aImtPqdtKYb//vin"
    cB64 += "BJnCBQKTnsJn6ZpSqtcv54IzOnHrzdtz4w27cd2123PV1UO55MpdufTiIVx44VDOPHt7TjmjPyef3pfjTh7EUccP5rCjB3DQ4X3Z98A+7LF3L/bQ6mePvfuy"
    cB64 += "27A+7LL7EIbu2p383geSt/etWJGYYihDTtvWcjEuKyotQrUOaEfByGq42m7yGwymztYgW3j1PiFZMap9wmuqIT6PltkbtaozVG8o16pT7k3uElQeI6T5+k2T"
    cB64 += "TKeYPn8VP05fyOmnHMy6ZdUcfsgzTJ9WTqTnvpiSHXBkQb2g3RoXX/x9sUe5Mio8TJUH2gH39GwqwK31SUo20pXYssI1PiT0nG35xGW1akRJ1LxaTygmrbey"
    cB64 += "uezWe+i/8xCuvfkLfpm2ml77doah+/HeJw04pQXib/DFyKuyiWxK4077EHfjQo45bRB99u7NLZe/yCNXH8Z+O3cnFFLfjE3Y/1ezZL5RHBMiIqXsPLQfl114"
    cB64 += "NDdecxy33HAMt910JHffcDz33XIyD992Go/dfTZP3nsuzz94IS8/cjGvPX45bz1zgazU+Xz82sV89tblfP3BFXz78ZWiq/juk6v59rOr+f7LCxj7+XW06FSA"
    cB64 += "KY6BZn0QtLZu3xLfsaivQu7JgCyGHwx4nS+A8QdCg+vX6lmD7m6swHbLKSxx2VCXIhZxsCzV5bfDYHxbjgt+mryCeYtWc85pBzJ3xmoO3f8xVqyxiPQ+Hqd4"
    cB64 += "O1JuRCjxsBtd0okQNDrEGhxM0FYgS7D6EPmBlRX5Wgil4haWkyY3YmEc1U17mYYTvoDme5o0RhTSBHA54tRzOOfKU3j5hdl88uZ4ctrZtD7udEaOaCJZlosn"
    cB64 += "+d06V1dDWDoILxpFeuUU+g9tydnXnsLdVz/NSQd15vhDt8MYk6FMY3/hx/oL3/5hn2TV1baRDYCwzJqvAXMzBI5mqKvVoKvFgBvSLNPV+wOlCe59C3zNrt/I"
    cB64 += "071nWWRIivGJKr0QYnVlI+XRKOmCOL4GI6QN5sLiPAJ3ExeoUPxjpHBLgEIWxZKLNNUeW67IqlhYgXVZX4khScuO2cxaWkuX5vkCmYUxhuDwFRPFvTq+/nYe"
    cB64 += "1U1xjjpyd0Z+NZXDD3uW0roiIl0OJZnVTSmZGL6CduP6GIE+7MdpZzbhVm7AaGfbJAxGrlo+kCDCN43qp6xrOu5g/AS2VvYpRfdBX1x8mkRxCZCU7hpF7QcO"
    cB64 += "45ZH7+P7CYu497Z3sbMsWl54IRO/dkiuL9CkUmGtlLURiaW+RypmkFj1Kc0Lc7nvpSt5/P4v6VHUjNuvPQH1XIX/utP664r9nUsZRw16UpzB8o0y574IkSWy"
    cB64 += "sb2wKPInFDyH9LyFNBQYKfjPCb3bQrZyTuCwZG0ZsebFAnMNyLVFBbJodghH1iDVkMBrFPjqNVT1SZDr9GscvJqUVnIpuTFHcZNk1OouHfwPznk2Ja2aMWHy"
    cB64 += "Kob07Ky2PCEAPN+RdfJ568Np+OEY++7Xh49em8pZZ75Gk2lFVpfDSGS3wjgOtlOnawO+AGZFErTJK2Pz9PfI0y6DZwHGU69EioHQ5LM8HySrKyvmkyCYgA2y"
    cB64 += "Ygk9JzRpGlU6LUmCYD9c1J1n33mF0to4l579NWm/iebHHMGGadkk14hnehMk60DJNCuZIty4nKZlH2KZBPe8fCHfjF1N7bpFvPTMmURsC9dW//jrjkD0v67k"
    cB64 += "tin113HxbZUzCF9bSDAgQ4G4v7339e03QvfB+y2EFAtB2f+JDJ5AUak9lKbubchO1WDSzYgVZJMVMcQ1cFZNE66sji33YTXUYdc3YNXFCdVp2OrTsmY+bkOK"
    cB64 += "kIJvv2YTRiLbOYVM1qqrf9diUKiNrEo81cATz39Mh84d2Usx4FP3fM9V172Kl92NcOdjiGe1VlkPX2B0fU/YsckN19K9cC0bv3sBp6mcSOts/CL1qMiQ1RJy"
    cB64 += "OxryOkNxZ4fCTmFCShJbwd/hyVpVNaWJGxBcaJRQaRMmHWvJk2+9TMtW7eSmX6ViYxl5u+xEyvQUkBz8hCtxXfx0Apx6YvFS3NWfa9Ku5Pzbjidh5zPm/U/4"
    cB64 += "8OUryMmKYiw/M9kl+F91BqPwVxX8dyrkC7Ce1cT6+giJDrnkp6uV+M2iID+HHLkcR6szv1EKb6zHb6rHjcfxEkmRLFjCQ0ZD+4YWoZRLOCmLV98ocNSxhHY4"
    cB64 += "DZsoLIwBIeIq+Pgzn7PzHjuz44DOXHPZh9z/+EeYgu2JdjyUVCQPz46rrBBqpUDJzPwcl+75S1j2xROY+s2Ei6OEO2QR7mIo6WvRbUCI/r1h+24+23f3GdLB"
    cB64 += "otAIpLJsnm+xUvI1pgwKFQlpZ6POzuWSex5h3z0Hc+nl77FgailWz2Lyeu9PxbRKTKJKwKrSJItj3Di2Yst06XdyndM57JS92XnvYTx2w9u8/8p5tGpbAJZD"
    cB64 += "5vAzv3/Vj/VXlfo3K+QbI5gZ1sUTbF9YT1ZNmnS4BSUlLSmwLOrrEwq6wSTT+CnNdIGy8aYAABAASURBVFkk35Vytf1jCQzhiEckJ0ROoSjbJtXYqPgmiwUb"
    cB64 += "c+jdIoKl7ZqKugZuvP1l9j5wP9oJyKcc9xBvvj8eSnbEbncwTVah3JvAhYMRsK2QTeuWa2kfm8qcr4fjJmslUysiLduR1yJGm0Jok+XTSoAqEbgLKhI0La6l"
    cB64 += "8qcNVC8pRzDTyhXmageiQdtbDZZNhe0w5OhTOP2i47n//vF8OnwiJruOZgccwoaxdVgNPpYsre1oksiKhVNJQuXzcWqn0WdoJ0655FRuveQpHrx7GAN6dMaS"
    cB64 += "BbNMILORcvirD+uvLvnvVND38dNRsprZ3N03i9SmMH5OB9p06kie3GUicB9WNvg2WBHsWDZZBbkUt8qnbcc8uvfIldINA7uF6dZCA5OugLxWrFWermuzMFW1"
    cB64 += "9dx813Mce/qJRLPCnHTwk4wZv4Zoiz0INz+KZFTKtGvl1NPYVgg/kqZ911paOGtZ8O3nmFQlnmmOHepLKN2CxNz1lI1cyoL35/PDS/MY9dQiRj6/kB/eKWfO"
    cB64 += "pwnKl9TL3braCfBYUt1EWltJcXxi/Y/khkfu5ptPF/DQI6OwTROFhx5J3fcqnyjDdWtwNIm8ZBJS1RBfgbN5DHnNq7j4oRu4797hnH54f449dChuSKYr0Icf"
    cB64 += "kvABbDxd/7ozKP3Xlfw3KmVJP1WKmXYryKF/lktNsh1WXlvadWhBJAplDRZe1MIOF5CVW0hBTjYluVFaRGwKZf1YW07Vwg2snrSe1T9NRotB/JyOeKuqePmV"
    cB64 += "dznutMs448oLaKpp5ISDbmP2L6Vkt9sHt+VQ4tEEITeKTT5WzFc8Zejax6GoehbzR07ASms1aWdBuDeuSeJpZVqtFWtyZY0mQxxHCw+/MYWfNNgphfZKSidd"
    cB64 += "D+PFaUqkSTTYysbU0NhmB65+9iFqVlZw1aWvi081JUN2pnF9FsnyWpDVwlFI4Oo+XYOVKsfdNEHpl0pOeOBOPv14Fv1LQtx84zHYJqzJYIMR0AISgPXAX3tY"
    cB64 += "f23Bf6tyxqJeq6y+HQt0tWiMNIfc5pS0aIanFVvp+gaMUhf+5lriS9ZTM3UpG0bPZdFXM5g78hcWfb+A5T8tZe30JWxasQzfSimma0OyoZauQ1rzwLMvMmvG"
    cB64 += "Co4//EbWbGwi3H5/UsXd8N1cLO1XpoVkp9DDL8qmZEA+ZvUPzP1utALtmbgsx0RagWI6PLlrNyBHljehxz+Sn0qQISeJL8IY6tNpPL1P+y0ZcO0dtMyPctHZ"
    cB64 += "T5OuLSO3XTsirXoQ1+RwnAbtczbIYsYx6UYspxSvajZhZwE9LjmS1euzSa9YyrOPnknIN7LoIdCk1M9WndZW1foXr6Thpbqijg6tClkrMMXb5OA1y6NZ8zCe"
    cB64 += "hnntsnqcDVW4G0rRvhaU1+AqxvIakriyIq62nKzGNOF4EtNUK204WOG2dGgH9z7xBJ+8P4HrTn2Ixng+ee3PxCvuSypcgJcVwy6MYkqyiTVrQ+u+EJn/DSu/"
    cB64 += "H4cdX6BxnIbgD25YA+tiMgPr4DkpBeUpgUFXAcqkkyqTAk9XWSNf73BjbErEqI+UUHzS6ey70yBuOucZNq+rhrwUuTvtw8Yflyg9kyCarJerlNyJAGy12i5b"
    cB64 += "Aol5FOy0K7ndDmL9F8N5443TyMlKY4U8JJRk8dna4/8kyOQbSGtPMisSZkPax/SwsIosCktismQum9bKOtTUYcXrFPzXg4Jj0vW616DEmzCpJhx07zXhyxIY"
    cB64 += "uRNCWZx3zhBeeuQDnr77GTyrhNyBp9HQrS/pNh2xO7fGG1hMenARVr8civol8H/8jvVjvyScnoplZhMxDYQ9WTsSoORqkNbwBDBf5KUTAlsiY7WC/4QQNwVO"
    cB64 += "Ws9ynQKZF0qxOi5gWlkMPW1fJj3yBut+WU3IrqXDPiex+YdZmhBJwolGElYjoaAfkt1P1uA2rSLUOosWB57F0rc/4qNXz6dDfhGuieIq2A+MmcnEYlsHM2vr"
    cB64 += "qv1r1zJeBGwbTJrlCYtwK4PVMUZMcdcybUCvW7YZE2/Q7NYgpoLBTGJS7pZB9ZP4nkCgzHzmf/pK91Y4n769PF675yG+e38kJtSTaLejcSJt8OWarTwXq9Al"
    cB64 += "mp0gEk5S6NfQ9Pl7VE38VGHOFGL+QnLFJwsLnyaRxCMJSoK4aicIzI3nIF+4hYL/DFB7oJ7XRBCXGVkz1JeV6SzCsUYqvviRn7+ckqnfYuiulC7djFVlNDFc"
    cB64 += "HJPQHBNYlZC2zAb1ab7mRxNFB1/Fhh/G8/bte9OnV2vcqIcteSw//KsVM+K3dae1ddX+tWu5Qa81KIINq5SuSLqKOTyLunAWczd4lG+slIWKy0ok8dLxDPm6"
    cB64 += "/oE0qH5a39wmPMVNxYWqN/oFli1YCnZX7JyBxDfVEF+8EG/mFNwJ35MeOZbkhxNoPm423nsvkZz5Kbnp6RS768lxDdkCo624KoAZiguDgD+wZJnUiQDly1oh"
    cB64 += "cP2RZMGCeE1pFbQ4wHg0JD1yZ65n9tPvkJK1yu/ahbQn67m0Qs9xFXNEYIRXy22U6yzHNstptutZNG2o5Y7j2rP3sF5YlkXYtdlWR6DubcXrX4aPJ0kt6TBF"
    cB64 += "jFWLbSxhI7ypjlot0edscORKU1iyLMZpwnI18wMKnoMYyI1r9ovSTTjahvGNS/nmTSSqy7CtttjR7qRSWXhyqX6yAtO4Ebtuo3JS6+jfwcbbMIbkqo8pSM8m"
    cB64 += "Zq8jX5axKGSTI5lsZfxRVGhcgYFgCrgYbTH56TS23lkClS2LFlz9wF0KdH4gk6wSKt+svILVz79EpLGJcHYR+V37UiXQOQKg0cTA8zCZNhp0LSXsr8fudQgN"
    cB64 += "uV05t+8mLj5zF7xQkoRAFrhIibRNTmubcPkXY+IkNXgmRLX2XxaOrMIbV0OutloqqpKs2NBIZnmvAcwE1gIYv5LJAC2F8VIa06Tw0CQSIPwoVqgbXrgraT+i"
    cB64 += "b5UYrfIyIPVVVltGgwd1YcOqL6lcO4ISfzHNqKQQ6GnCdNX3bFmvkJ7FHCOg+QEYBDBPVsxLqS2ByohQfJah4D6QQ5YUgcz4UPbxB1jlC7RatijpsTubJiyT"
    cB64 += "a0+JW1DfQw8iuUoqZNk24eW1oaD1vhyW+wt33X2SrFqIkJcl8BnQ5GEbHf/nQOYrEVtZUcVqy2LukgYapi3DXf8zrr2Jb9fHWLGmCcetwfcb8ZV7CixFEGj/"
    cB64 += "RgSg0cBaXiPGkkUzeZhwO3y7DZ6A4csNIYtj/AS24xKNptlj/66smvUWDeVf0CW1kmZ45BsYrG2gPsbGVuzj4xNS/bAA4ys/ZlxkTZMCvIsnwHpWAI4UvgDp"
    cB64 += "CXyW5LACq0ajgOPhpw0Nm1bjCuS5xf0pW7QRV4lWfi0Xkks14qvcDOF0lWTPIbvbfnSMLOHVh48mFLHAlnkX2ZJFD9sIYqh324zVvw6jJWX1TErk8dXCjTi1"
    cB64 += "67CaVuNEUbbcoa5SrkQb5L4s2R9IFsPXgP5G+GmMUWDjh7HsIoyfgyd35rseGmWMJ8goKG/WLs1BR3Vl+tinidf8RDfFdTGNZaGVYo9wlH6hKKUaeEflQ8YI"
    cB64 += "bGDwMoTxdVp42iLyU2kQsDLt+7oPKGhPcnlegz5JZgHe80NEoh2Rp8aJN+JKZk/gCiitbL/Rs52uJhWuJavNTnQKJxj+wv5ESyAigPM7HdbvxPefkq0vKxYI"
    cB64 += "triigcn1uUzTKtJOrZdnWIurraOGuhBudb0GVC4us7pLYYxI1gDFTgGZzH1Kc93VtwjIcvieAU9WRxbOEMcy1QwcmM9BB7Vm5Hs3aG90Km39CvLtRtoYjxNM"
    cB64 += "DkMiuWxWfGcLq4KNxPIJBsMOQObLMqkFBBpfAbgbrGw9F3wVzsgRxxeIfa9O11q9T4kikqcQ3xSSUC4PgcvHxQ+uAaHv/gaxrCBSsCsFhUW8/NhedGiej2/n"
    cB64 += "YhlfMvw+Z9Cv34fzPylXT8Hv0g2b2VBvUba0FNutwLWrMVYOdqXBVFeT+csIWQk0oBk3KcthNFAZ0sAZUaZ7io49ffOR29T3oHw40sDBh/WjZUklX75wM62b"
    cB64 += "VtNeQO2gsn0EnlOyCigOh5gdr6JRy9yEFSZIElj6ZsTUaCLIfulOpxYivtygL8tqJDcB0ATkoB2tKFRAE8KPY8ntGq8EO9yMlHJfBLw8fRZg+Y3kvn27FC/a"
    cB64 += "g2at+vLUXTswZPtWOJaTcdO+QBjU+D3o/wTIjAbYMwmMLI5FmqWbXZy6FLXLynCMXI2+uyFZgTrwK2rAcWQVZB2MZrexwYTwrS3kBdfgGUEhyIbbPrYHYbmi"
    cB64 += "wmKH087ZnRWLvmb6yOdo51TT3bJpj8vOinVOyGmNL7M1O1FPkwAks6MB9okKWLbKObaFZbmCRUhtKhGqC14YBDBfgIfAggrQphF8URD8Czyu6mJn42XA6GPU"
    cB64 += "njEOJgBbwC2UEBBL8ckhv/lArrigI0cf3EUTy1Z7YfUEVJjf67B+L8b/fHwDO+GTFiCWb0iRqvFp2rwZLxgwy2jyR1CiieD/fc2YsAZqC0FIXbH07GVII0nG"
    cB64 += "BSmOslImMzZOOE3n7Vpx+DED+eLtu6lZNJrOVg0dTJxeQtVRSiccWtiOdYlq5jt14mNngKlWxd3PxGIRTYCQyAhwRoAMQEMoGyzJhaM2mwhcJFrhZpBqXIzx"
    cB64 += "yAgQTAQQFvWs+roDXW2BLSfqC2BxuUmP3JydOOWoXC6/aACeWrZsgTpT16j273davx/rfybOvoQJaVCgrC5JZXU23sYEVFfKQjVh2WG8VIhwvQajQRbCSOlB"
    cB64 += "PCQLh4YDDZYJ4iG5quBqBBxLlsKSZcmKNnL08UNoXbyJUa/eQIeauQzxKhkkAAwK2xzasQu9snKYUrOOUi0mwp5F0goG1yOIg4zsi8YaC7Wpdh1ZH1+gx+SC"
    cB64 += "XQChGCaI92hQHxoxgUU2aV1TGFk9Y3y9R1x8vfN074p0tTyKSrIoLBDUPJdwVmd23qUTj95zGDEvpD4H5VT073Baf4c2/uFN+BoI41sE10Ur1mM5ylCtLCes"
    cB64 += "/Tv0DQXhQSrMqotrOymuEXPxAlAFQX5mAZDUu7QoRRCjGYENvW/frwWHHL09M0Y9xeZxL7C9s5ZdTJIdFGcd2KoDJ/UaTKK8hrlVmzHYeKGwXKNNWLIEOLIB"
    cB64 += "20Bw32R5NCquk83CD96HciCciwnH1G7QfpPeyprJbQYyeAJ6QL5AibiTOQQugdsSr9Yd29Cua1s2lW8Uj0L69evM628eTDQWFjgNVtAIf5/D+vs081e18vsV"
    cB64 += "kkVyBSbpn2XLKuXxWmHWrsLTst+4WYTCEWQg8BpqcBVH+cbCkgUzApJRrGU0dl7gnhT/WHaSvJIs9jp0CFHmMPnda+hYNZMdqGFPO8Sw5u04ds+96RnNZt2i"
    cB64 += "BSS0Bxr2IdeBAscIVEb1tpAlV9WkeGqTYq46tZdCh+1iQg52VADLtrEieQJdXPK4mg9iYsTMGFBdo7gupEdb7jQiHmHSRPNDDDpgP7r26sXsmRPw7Agd23fi"
    cB64 += "rddOoVVJDr6sqJgBtujvc1r9eOfcAAAQAElEQVR/n2b+0a0YCaDRkHYXLSvHbbJJaSvIk+WQ1rFzivESFn59PbZyWbZSCx4JfFkzP4i9XIeQE8dEYNAO3RjU"
    cB64 += "L8zi724nb94I9nHL2NFPsFtWc47Y/yB22X57nOmzaVq/kaisTJYx5IgsoSEsoEZlQmLGoy5iUydguXJlIUkn1oQF7pIWzSlu3QInvyV+toLz7BZ4VhKfoEQM"
    cB64 += "S/ucIS1MItoJCGvz3NcihKxC8vr1ptMx5zPkrAeprXGYOOYzcXXlxvvz3HOH07NbDEs8DEbvA9Ll73T+nwBZoFKjYQpgNmfeGtKNDm5NOUauzQ+5eIUR7Ow6"
    cB64 += "uaVSXC3pPZk1I+uwpZ4DYWjZtSsDtutE7dwRpMc/zR6JVewoS9ctlsuB++zPMScdR8n8tZhxU2nelCBf1fI8C9kjcmRJi12LqMCWCHtUKaYKEqyFhGgm5ObZ"
    cB64 += "UWJ5+Vx01ZXM+GUWXXt3xc7KIizghkPIgsWJePXYArMXMtCsmOzefWl3wP4MueAi9r7xLnqfcjktO3Rh+ei3WD7tC/U2TUnRTjzx9GHsN6w7YZPDP+qw/lEN"
    cB64 += "/13b9YPWfJLaZlm1tgp5QFEVViTBPsfsybU3n0Tv/CW4635QQcVeni6a9waj8cyifRufUOlnhKc+yq71M9jDr2dAKMK+O+zChWdewFC7GVm/LKQwP0JebhZG"
    cB64 += "brNA7iygHFmawAY1RMJUaegTKY88JXBbS6Zg2JuiYfoedyQf/jyV6+6/l/yiXFoVZ2OymuHlNCOZZSCrK07XA8nb63i2u/ByDr77Zva//jKGnHI0HYb0JFe+"
    cB64 += "uHHuBKa9cTuVi76VtfNo1bobr7xxEkce2U0gtdQy/7Dj3wRkGghZC+MZAtqiTV/3uvMhrWRoKBli/bpSBddtsMNJWrTL54l3H+HI4w7lvfueZN63w/GSFWAc"
    cB64 += "Legi5BUVUNyimmj1SArXvEe/xqns5FfRJxJlnz324vQzTmP7tIv74QiYMxPT1EhMAX92y1YU5haRL5BmyUI1RmMstmGtkqRJPGzjE5MbTmbFaH7IQdw5fhw3"
    cB64 += "vfMW7XoKDFpJWrJu7VpGEXKwI1k46Tyi2x1Bwe5H0mnvfejUvwMRq5b0mvmU//A1s195lG/uupg5w58iVVsNVjF77z2E77+5nkMO6EHIygLFeZov/KMO6x/V"
    cB64 += "8DZv14C80xaSRlPGoklZUocUTmOSaWO+4t47bqRz19aceYbN/Q+dzKiP5nD1qQ+xbpHcnAkRikbJy4mSG9pMbvWXtNv8HTs4S9nV1LBHtBlH7bE/R51+Bl48"
    cB64 += "waI3P6Jpzjyi9XWEq2oIb6wiXddIMhQm1bEdS9uU8Ivc8fKmGlLGw9EGdMQLQVYRLY8+mlNHfsr5H79H6yGD5AYtTQiDsRx826aolRYmdg6RxAbYMB7mf0Zy"
    cB64 += "9J0seeZ8Rl59Gp9ddglf33MLP739KqtmzsZLR+jVeygXnX8sX399C198fQU9e+YibLPlCG+5/IN+rX9Qu9u0WaPEoy+H4MpS+L6HEdlOmsSqNXz30FPctN2u"
    cB64 += "PH708Sz88kf27tKGpd9O4bJjHmDcpxNk5uJEqVbMs4JocgIF9R/SpelLdnQWM8yvY/fcfI4ZdgAHn3w8Gxsq+eCNV5k/Yzob3TpW0cBGxWVNCt7rtIrc2FDD"
    cB64 += "gtoyvls2l0WbVtGkxGmuAv0SyRfJLqbd6Sdy3qTRnPjhu3TabV/8cBaWZTDGSB8WPnGChUbrtkVk18wivvQz7Pgs3PplpMrrtEsRISfWlo7dt2Of/Y7gkovO"
    cB64 += "5KUXrmL+nMeYOfNGnn72CPbdrxMxuXKLiHhu43Mr2f1bgEw2TN33sAQuR9ZkzsiRPHHKqVwyaEfeuOseFqxZkPnfc035tXz83EUs+fIeWiW/pJX7GcX+CIq9"
    cB64 += "r2jn/0BPfwU7uE3sY2Ic2qEzJxxyCMMOOZTFq1bx+ruvMf2XGch/EaQLbM/GuCFqFXstlIud4FYzrmIVszespCYuQATAw6a6W2/a3XYLF86dzjGvvkjz/gOJ"
    cB64 += "+CEsY6FkPCGtXn0BzTdgCGFrwdC/Kxw2YC3nndCOW24+kKdePIdRX1/Owl8eYN2KR1k45ya+GHkmDz12CGecPoRuHfKJWiEsASvg4VlKhkgm/kmOf0qQBQoP"
    cB64 += "9GN8CAjNcaPBkNdBqSb8YOnu+nh6lwblthKU/jKbz26/m4t22ImbTziZ70d8RlVtFfVOE0lVDFs+7ZJx+jXOp3t6OcWUUmwStBMY2olPfxPmiGg+5/Xsz2n7"
    cB64 += "7UeLTh35+oexvPfx+6xYtZgsWcbWivkKbYOlhGZ9LJvVIZvZslZztI9Yqg11TzFZUnzq8gsJH3I4e3z0LufPmMweN99Gdut2gkAEywMn5OPaPp5kCjpogg4b"
    cB64 += "X7cRfAuGDuzE668ey/PPHc8dNx+lxcUuDNu3N516NCM7L0JIeb2wgBo14ic371s2nhFjgiMkdUV1o6t+/xlOdemfQYz/KoPGE1fSOSJXc9SxLRzNeFsfGuyQ"
    cB64 += "gAON69fw43NPcfMe+3G53M87Dz1M2fLF5CTiFMqqFQmcHVR+iJtFLw1kjmyFq4ENeRZFio+6KWt+iJ5vyG/N3R2346CuPVlRtYl3FL9N/vEHuakmClW2DTFa"
    cB64 += "W7lkax/RFgqCP60Op+vIdlOyRp5asajNLYFhwxjy0pNcsGg6R494i/aHH4CbG8VW9yR6BkAyYAhjGTJ670smiaa74FRnQ2AEHEtgRYXVHGCkAZGPgEjmHmMI"
    cB64 += "6umCAZHqEhy+7v3g5p+GfpPsn0agQJBgtgdqchTLmIBkuVxt5aS199NUVcaqDz/irRNO4rrtdmb4lbeycdp0wok6muHQVQPTRbO6d9hiUCzG9sp4FwhMrklR"
    cB64 += "YFx6y2rtETKcUZDPzR36cWy/Qfitcvli0zyGL55BaUUF+QJmTiREtpJUMWnIV91Gr560SeJaaXxjSFjZ1Ba0JHbQIewooF8ybwanffsVg846l1hxR4w2ty2t"
    cB64 += "LgUFsJygW/9nSSr85+u7L2B5omDGW0mfePVGFn31GR+eeS539hrIq2efwZwvPsGuKyNME+0tlyEY9ibE3lr2D5Pb6+EaIqkkNXJnIaG2l7HZT3mnkzt243jF"
    cB64 += "Sd1btWBO7Tq+nzuD1ctWkNPk0NqP0VIgLfBdstMOEWX6bdWNSpYcAS8lS+a270rr405il5de4FzFWSd8MpxB55xPfuu2hKyQAGjh2oZw0L4oJLfmGZmnfz41"
    cB64 += "/90ksn7PloxPxrzrF2k/cx+882VphIkt7zR46HDxcTW4KEZyFf80rV7DjDfe4qnjjuWO3jvxxrFnM++Dj0CbzcVKqvbT4A0TxI6zszkmWsiBWr31DmURTsWp"
    cB64 += "TNXri0dfWZsDmmkvsUsfDunSgw75+ayu2Mj4JUuYuXQ9cW2IRxQbWSFPKzJDvuUTs3VvPPIlk1E6IlHUnJy996P/vQ9y9k8TuXTOTA575zUGnnEipm0LfFk8"
    cB64 += "W1rUGgBLfQhrD9GWq3Y1Q+RpxUWGTHrI3Pwf/ZF6fr+e+waC4NYxDo5cRkpWIaWBNNK+r4+uEJfWc0p7cV5DA6t+mMTnt97LkzvuzoN9t+er8y+gcuSXFFeV"
    cB64 += "0k2uaohG88BILifGmnGsYqB9ClrQLZqloNwjnUxi2SHatWjPbt23Z6de29OuUxcajMOidcuZvXIx60rXK2mapMikaWY1UCTX19IY2gqwRZLJDoVwi0vI3mdv"
    cB64 += "Ot53FyeN+55rlizitFFfsue119B80HbYObnYdlhzxFY8ZgnM6iRgqT++3vrihyh4Nnr/x/P/7t3vBjJfOvU0s33dhF1LG8xG7scm4kj1jotfU0PplCn88MTj"
    cB64 += "vHvY0dzXox+v7ncAsx++D2f+TDolmxhsRTk0qwWnFLTjhIKOHFTQmcHZrcmPNsOK5GEKW1DQqTvt+/SlU49etClqSVbco2r5MlYu/IX1KxfJ8pXTTCAusSwK"
    cB64 += "LJ982ycXyWFyiGc1w+vRn7yTTqL3809w6OQJnLN0ESeN+pZ9r76ZtjvsSiSvAEvgdcIG1zLqERiP/xz/Cw1Y/4uyf3VRXzjSeGK7YKU8HCdB7YY1/DLyM0bc"
    cB64 += "eztPH3YQN/XqxUt77s2s626meuwYOlTVsntWEYe06sGxvffi2N2P5MADjmF7JUKLd9yFrO0HkTV4AJHBvcnp2xlaNiOeamLz6tVsWriAzYsXUrlxLfV1lTh+"
    cB64 += "goh6FrW0Co3EqI/mUJ/fHH/AUAqOP4W29z/AwC8/5vhFv3DUzEkMe+1l+p51Hs0GDsLKKRSYgno+KblRV9bXF4kdAZlAC5mf4OY/9NdoINAbRtYmQ8EM1X1Q"
    cB64 += "MZizRrFFQBDYJFe/Dg4uKSk5rTkdvPV1VcoKX6u2IJ7ylYuqXLGY+V9/xfcPPMzzx5/EXQMGcHfvvnx17ImUPfQEzWfMY5hWZkfscTDHnXoRF1z/CKc9+BwH"
    cB64 += "PfMcgx+9j3YXnELWkL64kRCNmzeTXLac+OzZ1PzwI7Xjf6B+6mSSS+fhlm0glGyUq0IpDUN52KamdXMadt4J//gTKLrmWnq8/BI7TRrLoct/Yb+pExj0zuv0"
    cB64 += "vvYKOhywH+GWrbCDFaDAmA4jcLnydA4hxVVRzyYiFxpyLWxdg0kT6Ij/HP9rDVieqqRFAXASNlqmGwHGKAi3cMwW8tEHKd1I2SEXIop/qKyiasFiFsq1THn6"
    cB64 += "MT6/4lJeO/BAHujRh5cGDOP7865kzccjaOGkOHi3ozj/mvs4/6nXOPXV9zjqyZfY85ob6bPfvhS2LMFdtYD6rz+n7uGnqLr8dqpuuJ340y+Q+OpzGudMIb5u"
    cB64 += "DbV1NWwIw9oWBVR06U3NbvtQd9aZxG+7HvPqE7T9/lN2WjCZ3RdNZa/vR7LLmy/R+95baXfqiRTKQpmCElA6I4QhpH6ZgGwb5AItxVBhJaRCvp7VV9+SDoSo"
    cB64 += "wCL7moaZq4Hgyn+O/7UGLF/LdEtACDUlCNc0QnU1tRtXU7ZwDqt+nMC8Tz5mygvPMPrOW/noogt57agjeWbn3Xlpj7355qTTWHnPQ6S/mUzrddXsXNSe0/Y9"
    cB64 += "hPPPOZFTjz2MQwYNYsdQlFaLpxMa/jaNd95D5YVXsPKSC1l77VWU3nMn1c88RemoUWxauoC1oThl/dvScOAeNJ5xDE3XX4z32J2E33+OlmM/Y+AvExm6YCb9"
    cB64 += "5v5ArzHD6f3C4/S46UY6nnImzXbfl2jn3lh5JXjhGG44iqeEpsHC6B//Of5hGrDqBarVixYzc9wExr//MV89+SKfP/gk3z36PFOeeZ2Fb41g3ZdjaJzyC7kr"
    cB64 += "N9Iubuib14Z+JR3pkN+SfELEGmsINdUQr6+kqqaMivJaqpIuTQqa6doDd6/9sM88A/vGy8l68m6av/kcxZ+9T7Px39J89jR6LplK34VT6f/zBPp8/Rk93n+b"
    cB64 += "jgJfhzvvpv3FV1Jy1HHk7Lwbpn03TF4xtgBkLFlZC1K2nLZ8mWwPRm7OltsOLJItqxQCuT7Z4WD1ofv/66cvPfwp/b30YRWWFNO1cVKvLwAAEABJREFUf1+G"
    cB64 += "HLofe190GkfdeR1nPvM4p7/+HKd8/AYnfvE+x476giNHf8Uh337JAd98yj7ff8KwcZ+y14TP2HPiN+yoPb5B34xi8JdfMPCjj+jzznN0fekJOj71MO0euZtO"
    cB64 += "915L+5suo/UVF1B09kkUyxo222cPmg3pR27X1pjmxfjZuVixLMgK4UUMbsyQDjt4tottPJGLZacxwQ6y/JblGq1YIeyE8PXsy705Ap5rIbfmiHyCFImn8j4+"
    cB64 += "CICursIgBPk4POlY73XiO3jBroA+6kQRAWmV90X8yluF/8czYLFl79ClIe1Tl/Kp14KnVpRKi1umvf+x+tZ/kGxbKnv4staedBCQ76uLmV7oqx68YLdEfals"
    cB64 += "TLC2ooZ6JZoDXeirdKfCwc3vSBoSC9/YasKWmKLg3sjB6GphY+lqG3Q1GNsC5ZJ8bQz7Wtb7oQgyK2hssewMC5RyImnF+OGXVVz10Ltc9vD7XHPfF1x73+fc"
    cB64 += "8PAnoo+48eEPuf/Fz3l35DSWbqwn6doEm93gICF0WgrmLUKyRpaCIt8EMlpgQqhBPMuIXFZu3MStT7zBNY+/z1UPvsMV97/JzEVrEQMpz+giBQo1C+XKb316"
    cB64 += "ODc88TEPvPqp1C9eBIe+G5ekSo6avIDrH3ufyx54nyvufYtRE34WDB19CQbMBIX/MmnAGxM++51wPf2GXUjPfS6k+94XMHzUD+qV/Zfrbu3XQHz1xqgFy/Wk"
    cB64 += "swQomW0EKGlIXINfh0YH7nxsOL12u4T+w65lpwOvZdLMFdK5hzF/Rd/E6W85f9P238Ljz+oGInt689E303jh4+m88NF0nvlsjOh7nvpoPE9+MIkn3v2ZO5//"
    cB64 += "gfNueZuhh1/DGVc9xbqaWhyj4RaoVP3/53Qx+pf2ozz77k88+/5snv1oFi9/PJkfpi+Q2m19BSPr5GnwH37lCx55+yeefG0qz789WqAKum0DPtI/NQmPK297"
    cB64 += "nWfen86Lw2fw0dcz6N2nD64SyL6sg+UZlf2fz2AoLVJsrK5j/roGSpty2NxUSF3cplef3mol0Mj/XH/rvviZPgopeJqMsvFsrHH5afYaxkych+tplRS0bPnM"
    cB64 += "mLuap177kup0iEYrm2WbKnj9vRGaiP7WNf2/rBVo+39Z5f+nuO9hi+bMXYSnwfF9lXdjxEyUIm0BFXtRotRiy06kyabRz+ezCSu4/NbnSXkxpBdV+MunjyEQ"
    cB64 += "vLi4EDuqOtpAt0S+Z1EpBVoBE+MJbLBkYy1ffjdNHtEDgbihrpG6+jgEX32V0QC98/FYNlbKCshShr16zjl6Vzq2zJdl0EAJpIiXKvzF0xOvpavXEZdr8tRO"
    cB64 += "yK2nOMule9siwtp1+IuVt+bjrzK5knni3JXscMQ19JQFPei0Oxg7bT6uvge6NxqDzu2LaVmYRZCOCac9SiIxTjzi0EyrQYyWufkdf4Kx2rbsjUWDYpKl66vw"
    cB64 += "dR+gJirFX37yjiz76V5W/nw3P31yP8fu31OdTmVmk6fUwg9TV1O6uUmyBFYqrWouvv65euNnKLAmvsY7LQq+uRRkW3RqV6KvCUFW7+SrN1bW42Yg6Ooa4pk3"
    cB64 += "v6U+FdF3sbRTJJTUKy2vw8+w86mpT/DsWyNJhbJV3qFL6xyuvfhITYSkQCa4ZuKppOoH/EX4KheQmhWwEHmB9fWzWLm6XLIJ9J6nMik6d2pBLDuKIyAjPr6v"
    cB64 += "/sp2+pk6vgTawsP/NSbc8uLXX33G9zOtuWrd07Omifj6eKqP5+hbOvM8duoiFq6pUXI6iq+JNrB3By3H4ion7alSu+ZZjP3iUV685yhevP9opnz7EPvv0ROT"
    cB64 += "iXECGRw1miKQSzVwpRw1J96e3gVv0viBACq6Nee2B5mk2LipisZ4AAYHI0U5ypzvrCC/MBYjP5bLgM4tuO7SYzSIvhSlgZTiU6qXiDeqsz6KnamoT/HVhF+4"
    cB64 += "85kPOOO6Zznnphe578Uv+HHOGhzPSO02Ibmyrm1biocv2+Zj6XdjWbmUY/TOY31pLZ98GcRWqLzJfJe2KN1UqQGw8f0QH30xng1V4HueYsA6brn0RCpq6xk5"
    cB64 += "dRVfTV7IFz/MZsGyMuqb0gz/biZXPPAe59/5Co+/+TmrSqvFB/F1CALuxStXo8bVtiOGhu17dZTFRuRTmUwzbfFGXv90Krc9/QUX3vkGl937Do+9+Q0Tflmp"
    cB64 += "uMnX4HrqQdAXQ0Kx1crNlbz1xSRuePQTLrzlNa66/02eeGM046YtQurVfuwmvp+2hO/GzcbVhA6w7imA3lzn8e2k1Xw7eR61DU2s31zH/NUbade2La1atGFD"
    cB64 += "eT2BVJbxMnInVHHp+lre/XqqYtwRnH/zS1x6x6s8+upIfpq5nHhS/fnnAplh3pKVuI4BDZyvuCimFV7fHh0wbiCsi295bNyskQ3ciDrqE6KoIES71s1IuRYf"
    cB64 += "j57DTorVTrj8eR557Qc++nYe74yawx0vfMv+Z97PZXe8QkNaIHE8AldgNKwBmD3N7sqqerXj4sh6PPX6SGoS0qcshYUnIFloCcvG0jKVcShrTPHIq1/gamiR"
    cB64 += "nDv1bc3hB+7IWx//wFGXvcJxl73ASZcqnTNtDUec+win3fw+z42Yz9tfLuSWJ75hj2OuZ+HKzeqnI+4wa+4qPOPq2aDG6NezM4EOEnp14Nn3sc8pj3HBnZ/y"
    cB64 += "4JvjeO2r2bzw6WxuFJ9Dz3yAS259kSbNLs+Jk9SgBnHk0MOv47w7RvDke1N549tfeH74bG55bCxHnXMPa6qbOPvmVzj8wpeZuWQjvvrrWyGccEgLq4854uLX"
    cB64 += "OOPKp3H8MB98OYVjLn2KQy9+jqMvfJXn3/g2UAqul2JVZa0m8PNyt7dz9q0f8uhbk3hz5EJe+nS+2hrHgSfcxegff0EzSXX+wvkXPknrf+HrVnzyVGfRinWg"
    cB64 += "TgcKRlaqKJpFSUGe7jxSxlPgmeC+xz4h+EtXTIqwW8/pR+9OKGx45bNJnHvjS6yuMmCFOGzP/rz10Dlce/Z+ZJk0aSfMm59O4vUPv8UYQ7eOzRUD+hmriIGa"
    cB64 += "+iSuVlrLN1bx1ucT8QTgmNIgVuBiVMAnxsayOikf3vp0AqX1IdVPETNx7r3uTMJKk8xfugFfE8QL+mDHeOXdb1m4aiOdWmcR86qwlLx25VBLG8Lc/eQ7OCac"
    cB64 += "sXQr1lYTTCBL9cLGZ0CvbpLLoaKqkVWLN9G9fQEnHtKDS08ewsXHDKJNgS9tocGO8cnoBXz+3Y+k5cLe/eonHnzuW2oTRXi+T9c2LmccNpATDupH705ROrVp"
    cB64 += "RnFuNqmGCnmGNMbz8WTJjFxyzHfIjzRRktVIr07F5OTlMGfJBtJeDsr64FkJ+nRvq0Z9Fqyu5eAT72CEJnGTG0LqpEAJ8SHd8hjYJYv8aBO+ePbo1V3TWDMl"
    cB64 += "I+3//mcbgixQmDorcWbPXyWQ6dTAGpOmeYdmPPCi3N6Nr7H/2U+yx1HXMXtxdUYxIZIcvlt3rj3/WOYvW8stj35IwmSD0hR7DmnP6w9dwAkH9OOmS4+kqwAV"
    cB64 += "AM8L5TNy9DQpxadju1YEVszH0jM0NsVJSOlvDh9NYzqWAdBBe++AkVyIpy8XubGimmr5mxff/QpjRbBo4piDdmbH/h1xPI9Fy9bjeWkNCKQFdOM3MeWTB5j1"
    cB64 += "+b1ccNIe+LYv1yrXLkBMnLVU7fiyzNU0JMAYgyXKjoXo2kmyafAt9XHMh7cy+bPbeOv+s3jyqjN57MaTue6iI7Atn7Ri0hRZcsvr8AXYz8f8QtJK41txxa31"
    cB64 += "3HPlaTx/+zm8ef/pTPrsDl5/9GqaRSPi9xT3X3cMxglW5WBrch2x52DmjX2ehWOfZNTbd+PhMn/JKrYY2LQmRBP9B3ShKu5y5hWPsrrUxnMj0lMdh+7ZmRmj"
    cB64 += "HmHSx3fx82f3MXvMo9x42WF0aFOMZRm29rC2tuKf1jPqiiCFrw4lHJe5C9foUUoyvoSH7bt3oL4hxcffL+GnOWupSYJnGhjSo5jHbzqNt566msKwzcvvj6cx"
    cB64 += "GdbsSWHJ9Q0a1Jf5S9czdV4p0+aslLVI4auzrgaxrsnoHtq1KcFzHLVs47suqXSKRetreGv4DwKKRVGuyzXnH0RYgPCMI7FtSjeXycpNYGOVL+W75EZdgfh4"
    cB64 += "whjKqpOUVdRgBFQ0SWyT5L5rT9OCoIAs2+PofXciGFRXZWWCaEp6xAXYOYtWkJIGjCyCr3rtWzWjKNsGY9O8pJDe3dqyVvm68dNW8N53k3llxE+Mm7wET3x8"
    cB64 += "yWX8OLkFzQQqH186tMgWtxCulcV1d77Mc+99TXWDT8xYDOnXBV+y5IYtVqzYIOBEsFxL4hoGD+xE89wQBbkxCrQGqamNs2ZTjfgmMVp4ZGl1P6h3Z4Z/PYnF"
    cB64 += "a2vUfhz0vrP0+MJ9F9GxJJuQeFuWRcfmedx2xclkW+gIibbuzFTfuqr/b60A6TZVcg3lVQ0S3gfjqQMwqG8XTj16H8JeE0JDRhmWzPplZx7CxcfuTCQkW6LA"
    cB64 += "ZeR3P6m8I4W5QITHX/6KfU+/nz1Pu4eDz7iXdZsasGS+w6pbLGW4GqA22jCPhlyV9zSehqRitcdfHU1lU5iQXMM5J+1Ft/Yl5MTCmTK+6ixfV8cr74/D9aOa"
    cB64 += "BA4XnHIo3VsWZr4vXr6BRNrCVxu4CTq1zmW/PQeASWNkdbyANPy+5EC9jIZ8smMRZs5drEcBJLCA+hbEYyHSNKlfT7wzlqGH3sbQw27m0HMf4+xb3lZy+jO+"
    cB64 += "+nEujvgZz0fCMLhPd7Xjc+pxuxHx45INtZTFxtowNz7ylerfyHujpkmF0rXa8AW4KdMXS1YjSmNZDjsM7kvg6sVIZ5ilcvNpx5ekgFaebVvkk98smxFf/Eg6"
    cB64 += "mBB6bUiyz64D5GLD0o70aCyMURvBN12NCfhLRj1vzWltTaU/rxM0HpAE8Yxm62ZSCjZ9O2DtYxRTDO7Tle26t2K7nu30bPBMlKTJ45EXPpZri8m9QJXyV7WN"
    cB64 += "aSnQw/cNEZPknBP35vJzD+Hysw/nirMO4pqz9+XaM/fkqlN255SjAhdoyQpFtWAoARwNiI/jR/jquym6hxJZsYtOO4TckCeQhUAWRgVZunoTqzfU6jlN++Zh"
    cB64 += "rjr3aFk6V3KFZTnXaSzCKuaj9YlWiF3JkXs0voWvdeLyVRvwQzGwgiJpunduS5a2wRYu36TvRjwDa5lmUO/2NKZsTr3yce586nMWlyZImRCD+3fgjiuP4v3n"
    cB64 += "L6ZtkYVxDRHXJiuK2uoIsiBH7DeUNx69hB4tHEV+1RhZLMdks7bK4pLbXubbH+YIBDa1DSkWr9gE4ovlCuyGHl3aYFsG35coknfx8rXCr63yBuPZ9O3eBlcL"
    cB64 += "sCUryzPy+ipoAR3ats7Uw9iZugZPb8nUQ4cxRr9bdwb8t67m/1tLwgbSzVu4HE+C/vY5Pyebrh1aErVdTj9+f3XUyVi0YPYuVUe/GjMt0IbqqFuqZ2RBfF3D"
    cB64 += "skJXnXkg91y8P49cfhgPa2Duu+JI7rvqWO6++mSOOXAHzXSPkLHo1a0TxlbZpLoAABAASURBVA5AQEahrtxNmCbOO/lAWuRlCUCGFiUFmC3IwDe/zmy3SXHR"
    cB64 += "MRTEbLVviWxmz19JcFjqj7yGFhbBqliWUiBzFNB/OWoSvheA0GCMx+EH7a7VYJq5S5armovBk1wOO27Xjc/Hz+abaetJ+zlqM82OA1rz7Vu3cNNpO9OtXTEV"
    cB64 += "FfV6HyYZTtKyVS6FuRG5eJ+o5Dt63+2Z+OVTPHrrabQpCRNVfyyhPmlyef+zsXg+LFq6mqZkIIeNJT20aVVEnvJySAY0XR1NqrmLFbqYQF6wdd2uX1dd0USJ"
    cB64 += "qG0HDYgebDZvqpbdtaQ/C9SLwDgEFlFqIHOovcx1K34CjltR7c+reIiNFI7lM1sxgpGSLN9I1BCd20h52Vn4hDlin35SgqvKtp49XDvM0298gaNYqkVxntIR"
    cB64 += "RYodwpqUNgmtIu9+7D3WlyeISzmNvs16xUufj57LWyO+0kCHxMdVy55WbUUEerU1U42UG4C0veKJS08/hLAAaxOmTZsckJUzRjGIrJ6R69ixd0dOOmwXQvpn"
    cB64 += "5H68lMeceSvE18OoPTFnTVmNsvgQl7Zf1Cpz/PSV6hdYVpiOLbI469i9FOPVUlljYwl8xssh22TRqUMr5ik29YxR+RSWuBYV5OLL6lTWWdypBU7SyhYgmwh5"
    cB64 += "hu7t2mDLIs5fuobvlJ9r1ETJiyQ585jduPTcQ/HVB+EcIyuVkx0jmFxL123CsQ0YB9RCRN/qU2ni6ltDQ4Pcoc/0eUtwLV/tpAQgjx49WpJrYGDf9pJLOpTl"
    cB64 += "TKveZ9//xCzFlZ6glvLSrC6r5aOvxpFIudKF2Kt08Ls1FPR9a+r9WR0jFbjqZFI0f9lGKTsmCmEZQ5+eXchIaSzlwnKUae6PqxgMAcyzcpi1uEKb6cvJMmlu"
    cB64 += "u/gEIpar8i4pDdRH3y9nu0NuZ/vDrqffAdfQZ9/rOfWG96ht9KQ0C6MB84EWmsEI5L4AZUyUkAfnnXoIzfJVRubIWIZWJcXYePhGFssuJGYnuFdWMcty8DUI"
    cB64 += "YKhujLOhTKtefBzLJi0ZPh41k4MvfpG9z3yYGx4bIcCrb1aawliKV+69hPyoYa5SNp7a8NQHP9RIcesY+Xl5BKsyY6XwJBcC4Lc/LWfQgVfTe79LmD5zFb4b"
    cB64 += "BUJqzWhx1Fn3LuN/WcHRl79Kv4Nu5YjL3uTIC1/gvie+ImVl44t/zNTLIxyosj55OVlYOHh2CC8UZcG6enY45BqGHHI973z8k1baHmvWblJZT/2xMCZJh/bN"
    cB64 += "QXyuuehQ8u0G6Sqm52xWV7rK4z3OwIPvoN9+N9Bv3ysy6aRQMFYIoBkdsVWHtVW1/kslg8GnSdnlVcsXg1eL5ddrUJs0Y7ogrOH7VjAXFUvtoY41EfLrhIs6"
    cB64 += "DXCaF1/9Cs+1OPrgobzw0Kn07hglasdxlfVudEOsWuNQWuoSzN5enbPZd48hmXsTWC4NbucOJYRoEPBq1WYtPTvYnHX83lhKR/hAkBduq+A/ZBoJ0UjEq+eE"
    cB64 += "Q7dn9x17qXwYI+uHfldtrJAVCIFmN1JqcZ7FoG4lTJ+zULmmzbihbMncIEDk8elLt7P74J5EbJ85c5dgeT5G1s6WzD27diQmF3jS4Tuzz6DOZAcpBpJ4sn4B"
    cB64 += "iPv068Y1Vx+FbVVjewkivk2r4izdu8p9NWTqbq5sYszUpUyYvYLGeJKYW8F27SzefPQydhggQJoUe+88kH3klmOyNpbxCIC+sbqRuniCYQftyYrSdbJEcclm"
    cB64 += "YSu3V6SJ1aNdOyCb3bfrzKevX8/g7llke3HlKpGEsHxTGas2l2s7LMyw3bbDGB9McOrK1h3bBGRB85aUHCx1P3/rQe1N3sVPI+5h7Pt3cvqhO2UkM5I0WJEN"
    cB64 += "27EfMz9/iFmf3c8vXz7A9C8e5M6bT8cPu1iKq044cDd9f5xpI+7lzXtP4oHL9uKh2/Zl+MvnMfubh/hZOZx+XduKm8EP0GvgwJ16M3nEQ8pl3cfkT+7hszdv"
    cB64 += "JT9mYTzFHZrrNnHOPnovJnxwDz++f7foDu678SzcjAJtlfA1CVA8tgLPhCWvIWA9sEsR3711G289dBF3nj2MR686lMkf3sPE9+9jNwXwIaVd1G3OOG4/pn1x"
    cB64 += "t/pyLz9//iAv3X2uBi2LZllhPnr+Wr555zqevOFInrn5GCZ+eDvfv3INJ+81kPHv3s7E4bfx4/DrOOLQXRFeueaso5j51f28/9Dp3HfZAdylmPTVe05mqvJ0"
    cB64 += "U0Y8xeF7bCdgg++FMvw/fuUGRn90DU/ecjjP3nwCI1+8jjlfP0xPufIebVoy9qOHxf9GJnx6O2M/eYhm2T7GcjOpkD0G9mXMiAf4+ZsHeeOhMxX7HsJzN5/C"
    cB64 += "d6/dzpIxL3DDmQdLDxYOYcnmSy9bd1pbV+2PtTJNa7BSmo1EImzXsy079uzIUMU7u/TpJBeZj1SCZVyEIrJDhj7aOO7XuZWurenXUdd2LWVRYpkZHTKGcMij"
    cB64 += "b5fmnCyAXn3WoVxx/IEcvktfOrXIRgstbI2Gb3m4wT9ZjqysLAZo1TSgRxtd29G5pISwsfFl5fDA86M0L8hlcK/2DO7XnqG92tAiJ6Y2LQ1WUMComM+CFesJ"
    cB64 += "+mOJpyrRrWt75JE4fO++XH3+YVx68jC279EaY4dU3sI1BkyETm1LGNCltbLkLemva+uSAlxb8imRG6TKdpblueCEfTn3mD2ln/ZYVoRmxfns1LcTg6Wn7aSv"
    cB64 += "tiX5skQxjPrVoaSQo/YfwtVnHMz1Zx/CqYfvTJ9uLdR3D8vyAYMxRv1zpSufncXngmP25byj92afHfpQmJuncrZcdrZykR3YsYf63KMjvTt3UP8ku4bCMxZG"
    cB64 += "vLJFfdo348RDhmgFvx/nKn0ybMcuyrP5+FqsecaTjoyUyFYf1lbX/LWi8dVZX4Mlf9/4wwQa7n6CzQ88waaA7nuUsgefoOz+J9l075ZrxUNPU/HQU3r/ZOYa"
    cB64 += "3Fc9+gQVDz+ueo9soft1f/8TlP9GDz9F+cNPUxbUC+iBZygXVT74HNUPPU/Vw8/8GQW8yh54hLIHH8nwrXpI3x96jsqAHniO9Y89y/pHXqZy4gxStpHFC2EE"
    cB64 += "uWWKrXxdg9UnJkHnLi3x/TRWKknFWyOoe+BlSp9+jtpHnqH6UdFjz1D1K1U//iRBP6oef4Kqx4L7F6h69EWqH3k+Q5WPPElANY8/recnqXjkMcpFlY89Qc2T"
    cB64 += "T1HzxHNUqI/V4pehR1VObdSItrT1ApXiV64+BFTxyLNUPfYcNY8/R5XkqZT+qh97XM9Pqtzj4vWE+vs0lQ8+JV09oTJPUxPwfvwZfX+a8gefFD1FpcajXGXK"
    cB64 += "7nuaTfc8w+b7n6PsvmepuPs5Kj8fg6VFQMiHuLwMW3n8zSAL2rUEtIhnqF+/ifLpc2j4aRaNoqbJv9AwYbpoMk0//Uz9+MnUfj+Ruu91P3YqtWOm/EpT9W4a"
    cB64 += "dWOnUz9uGg0q1zB+EvW/UsO3P9IoalKytmn0T9SP/Ym6cT9RK6rRfY341X6v+r+R+DSMn6lyM9TeNGrGTqJ27I+ZOvUTJuKOnow7ZhKplSuxBaZ0CGoV1yxe"
    cB64 += "vgIT/DebXhPZbpLB/XpgI+viRNg4aRKVYyZQP/In0Y9UffUD1V/+SN1IySmqHTmZulFTaBj1Mw3fBPcT9DyO6pGiUeOoUe4uoCp9qx79M/XfTKF+1GRqv55I"
    cB64 += "7VcTM7xqlR6p+5VqgvejJlKncnWqUzdqgnQg+u4HGjM0UVe1881E6r+bRMN3U6lV+9XK5Ady1Hw7hSq9r1Zfa6TnavGt/moStSOn0PDtVBqks7qxE6kZ8yPV"
    cB64 += "Y36gVqvL+nGTNAbiNX4K8UmzSa4qIyVvoHCZqBK6wVhvDf3NIAtmvSsTn5YL6XDacfT84mW6jHpjC43U9du36DrqA7qM/IDu334k+pBu372doe6j36H76Hfp"
    cB64 += "9u27dP3uPXpk6AO6fzf8z6jL2OF0FnX6fjgBdRsdlHk/U6/bt+/q+g4Bz67iG1DAr9s374nH+3+gbt+9T7dv36PrN+/SSe21V9stTz9WsUYY2/hKiMZ59KYz"
    cB64 += "eOeRs/nwiYt488mrlIFvB7LQaWX0B7z0GN3GvE/vbz6izfiP6Dr+PbqIOo19m46iTvr2R/qALuNEYz9UOdG4D+kxevgfacxwuqo/AXX6/gP1STT2HdV5V/3c"
    cB64 += "Qlt4v0PHMW+K3lIb79Lx+/dVdgt1HPMBHdWnTmM+JENjP1DdD+mSuUo/uvYa+x4B9fz+PbqNfVf839P39+is566St/t3H0nnw+k1egQ9JVNP6bXH6PfpKv10"
    cB64 += "HPUaHS49jVg6jGwIviVzxtYdfzPI5Gw0UIaIfLxtRzG2VmAmjAlIsYcR+cEyWEK6SlsgMPpWVEIrKFcZ3worfoGEynh2Cs8CX+X8oF5Aink8Wy5Z8Q3Be5Xz"
    cB64 += "9awG1GMVNuq8ZpsaxrfsDHmhEK4oWNr7tq2itmLCCIgXQXsqZ8vFh2R9feOpQY+snDyOPWgPTt5vRw7fd2eO2ncIBUpserJkEcVXIbkLLxTGF98o4idZjJ4t"
    cB64 += "XW3xtP6MQpk2zR/ehVTPSCYLLyO/JXEjBHVD0oUtPVjSHeK1hUJY6q9vqZzWw76x8TKUIjiMUje2MVjGwrJsjMgyelad4N6oni+eQX1NHwwRjG2JQqC6qkSg"
    cB64 += "Q1/vtpDks0VhG1/kiUzQt3AUS/KGfYONxdYeW1/zr2xREKA24bO5Lqn4JillpcG4eGrZUSddXV3XMG/+Ghob9KBvPq5mj6ey4Ngq7mlwjQJR5XeMwGE5ITzP"
    cB64 += "0CR8fPbNVNaX1oEUYemdnSFXwHewlFJAh28MgRzBb5Bm0FDzzcTZjPx5EZ5vCFbGtu9hez5ipEEBS7eW3llaBJhgF0Jq9iVDYLUD2Y0fUnkLK3jQN0/f/kgB"
    cB64 += "Fw3Yr9x8fdcttvhYouBr0KbxgrfBU3BVg5mLkcu2JYP6q99vJi/is3Ez8LwQ1TU+Iz6bSlJK88TT13c1KxnAeKrju4FqRUbv0qrjsWTFWoK/OnElryc9uFYK"
    cB64 += "qRtfz76A4wqgrjrrW54EsVXPxlafLOnF4IBx8CVoUJetPKytrPdXVTNGw+rD8+9+wRV3Pgnqh+NL+a6ApgG1NYC204Tj+nw0/CuqqutVJISvb9KQFJfUDkAC"
    cB64 += "42oGq2zw3rgCH03Up+LaQH8NKzusLZksfKsJT0lSx3ikPIOrQXDFLRDU18C6JKQyRwlWj7SU+/JH32v/shxLQHJkJVLi75DCV7rD95Nq3s8M5ldjf2ZdWSOk"
    cB64 += "U8o1JSD4iw/1yRG3oKyr7JKjdizPkZxpjPJROGm8tIsvuY3eo/6lVcfzfQJKS6i08UlrAF2TUu2mTF8t6cWSHMbzcFU22Fd85ZMJrNlQA1qAZDeL0qjyr3/w"
    cB64 += "sVpPqI8JbVk5OJave0/SN1LRWM9Ho76XVBJVQPpm3ETmL14u/g4Bb0/6C65WOpmR1UjXwV99GC+FsRJ40mGQ2gnkTWtCu9KIGkfiSuqtO39XkAXCSbf8sngd"
    cB64 += "HXsOCMaJDz8Zx/hYuohIAAAOUklEQVQ563j8za9lTeZJmVGqaurZe/8dadWumJp6h1c/ncyT+r5wdSVpItRqoEaMm8V9L4zikzE/kxJQv/puPq7bkcqqJIkm"
    cB64 += "DaoborQqzWsfjuGJ1z9l+qJVOMbCaLBMADgvysSZK3jshS+YMHMlvyxcxZBenfEE1i+1x/ji26OZOFV5MjcmsY3acPhi7BQuvOUF3vpyIhuqNIBNFh+O/Jmn"
    cB64 += "3vqGhSvLcL0Ys+asZoqy9G+M+J5FG6oZ/t3PzFy2maffHcnnP83l5+WbeOKtrxg9aSauBi0YuEkzF/HYK1/y9sfjqajVMEq2H+eukl7W8Mw7X/PqJ+NpSHq4"
    cB64 += "AvTcJWvp011ypj2++GqKdiRcQtktSCtWSjtRRv8kXi99yQcjfqC0Is2Dz4/knhfG8IEWJlVNKQpKWjBoUF+B0c38qfajr4zmzRFjSUo3a8obeenD0Tzz9jcs"
    cB64 += "XlmFKx1W17m888kEnn39KyZOX4grq2YCqyYDwVYe1lbW+wvVAmkCMpq1adJatS2Q0vfYrjuLSzdwwa3vMPzLH2SSQ5x17bM0pDy+mTCftz+ZSE2jwzGXPkJl"
    cB64 += "bYKQYqRTrn+SRin6khvf4cXXR9ClQwvycmTpFKckZG12HtqVj7+exjMvT6C0uoZ9T72LdWtrpMAwJ537OJsqqvClIE8rxne++Zmzr3yE4qICXnvvO/E19Ora"
    cB64 += "nJueH8Xbw0dT1KYjF93+KgtXlwqYac16wyIBCSuPzsU5shJw2Bl3Mn/pKohGOfvyl0jKQj789k9cetOLrF5ZQU2ikUtu/YCX3/mSpPp1mso8+8YoMIaTr31e"
    cB64 += "E6KKN4f/wKXXP0ML5cW+GT+di259VgMJdzz6GTfc9Qa5kTxNwLG88ukEahp8qhtq6d21BTWN1ZTVB/ftePLlj/lqzERG/jSd25/8hC7K3QXhXLKpkTmLS+na"
    cB64 += "uYhmdpTlazZy1/1f4kUc7n3qa66/5zWKS4rIzY0yd80GDjz5burjKVk/J/OnVOWNKS6/42XG/LKK7u3bgnod8gV2AdIPpfW8defvADKzRRLf19VQUdNIRXk5"
    cB64 += "vbu3Y/aCVfTt0ZaHbz2RYXsNIBJqVGBp+Hn+cjp37sQ346ayem05deWbWL54GbWlFcxZsJYffpzC+8/dwcn7b8deuwyirK6JZLqJCRN/lJIaqPWr+HzUPHp0"
    cB64 += "7cAdVx3MhacdIL4FLF69EYODm47xxlufaqP5WM44aldOOHwn2rYtYGN9itc16K2LWjJz5i9yDGlKZVUdKxvbjhD8devAXq045rC9mDxjCavXarYnbNYsWk9d"
    cB64 += "RbXcaYhf5s3j+iuP46brjqNa70qahXjozrPZf7+daJaf4JFbTuW4Q3YjpkWAG8vj6Vc/5J4bz+aMw3bi6GMPY476Xt3gsHJ1Pc8/cBGnHDeUnXbuxYrVq2Vd"
    cB64 += "SmnRrDBDFdpUTySaJMdPeApUPStCLCef8s2bWCJrt++BuxJsyqeb6jhauyaHH7AbizQhOnfvQGWNw2vvfME7z93MOYf34Uh9e/3dyey2az+uPHV/Ljlzd21F"
    cB64 += "NbFyUznNYgUsWDiXRE6EoUN7gUmgearJqkUDW3dYW1ftf67l61MgVAA1uXvmLl1NjmZ+i4JsZi1Yp/3CbuQq2Jz+y0q6dehKKBRm6rxlDOzVgfUby+jdsztH"
    cB64 += "HLonJx5/MJ++ca8UVEl2QR45edn4iqU8gffkS+7C1qrszHNOJZFM029AF1at2kSHTu3xjc+6DeWkndoM6MAiqThn3YbNdO/akYDHnLlr2a5bHyrLK2nWspAT"
    cB64 += "j9mL4w/anTcevoZd+naRnfQI4r9ZMxcwcGAvgsz4urVlDBnah6OO24MTT96ND969nPL6SmprG9h3J00Y27B4SRV9e/egQFZkodxx9y49aBELsXDZRto0Lxbw"
    cB64 += "Q6wv3UxXyeFISTO0J9qrY0vWalPeCTXStVOJFjMR5s9Zx4CunZgxZwndO3WmvrGBI0+9no66P/G0kxW71jCoQ0cO2L4TH75+JaO+X8oDD4+god5l1co1DBrS"
    cB64 += "Dew40+XG+/dtTmVZDUZj0CrzhwRGI2RYuWql9FUgfRhWLa8my8ujY/NmPHTHcVx26qFcfeULzJi6FsvPVXmNqnF03brT2rpq/z+1pEAEBk92ZN6iZXRu3w6t"
    cB64 += "hFmwaB0D+3RRxyIsWrOJ/v26aPO3iQ2lGxmi94O0l7Zk7lwmTVnA9xOmalM4wYCeXaRkj3ue/4ynPxyLPCnrNyWorajjpRc/ZMmipezafyC77dqVr0f/yFNv"
    cB64 += "T+SyW17ltFP2pl1BTC7bwsQceorPS298qVjve5577xsGy0L1aVuMcq6Z//h3pvhUV5cSi4Ykn4/RWFRWxpk9fwOTZswR/z7Mn7eQKZOXMG3yKkJazS1bXkar"
    cB64 += "lu1oJhfuKXZZuHwN3fq0IIgD5y5cQs9+PfGNx6R5q+invhZGLIZuP4DbH32HB9/4lo8/+5abLzmRZWvW0dhkuOX+D7jmwc9w3AZZo10pL6+mtqqG1bLo9Umf"
    cB64 += "hqoGnn76fcIa8GbadrvriY+ZOWsDCizp0j2feCJJPBXh05HT2bgpzpw5KzV529BXW3c5eRGuuO0V7n9xHEuk+721Tffhh5N48u1vuOS6FznllF0oLdus+Gws"
    cB64 += "FYpzw2GX4uY5kj+5ZbC1iNhy87//tf73Vf5yDcOWf75lsAW2vTWr7rn6KFzf4oZzD2D/PQbja/V31O5dOeuEYSxds5nC/Fxatihivx268f4r1xGN+XTXfmbr"
    cB64 += "tq3p0rKYt5+8hOmTF9KhdSHNsgwfP38deTlw4lH78NoTV9G+eS6H7jWUN+89V2BOcf+Vx3L7hYfLhtlSkk9Mcrz52FUcuG8/enVrxfuPX8Lh+w0iryCXH965"
    cB64 += "We8KiUXUZrdumrmWQBL0AV546DIOG9aZnOx8durTmeEv3CAX6kj5EclbQtdWBTx+0xF4xiY4jt2vL2cdshu+5bL/Ln257NhdcEwWB+zQmatO30/y+Ax/6SaO"
    cB64 += "3b8/xbkRfhj+KDsO6iEdbODgPXtw6N4D2LVXPt+8fgtFeTGuvOAozji0H707teYN9dNJJrjivMN57rHLiIYtthvUHSdZx61XHcZ5xx9ASbMcRrx6BS1zLezs"
    cB64 += "KDedt7f4DiJXG7Cj37uf3Qe0pXvrIjo0L+HKMw/kydtPJxZyeeq+c7nzqmNpqXitXXEuzSIWX79/N326tgW5ZdtHo8pWH9ZW1/wrKhpjGDSwHztv35WYlWLf"
    cB64 += "3QYqvohiS+odBw9i48ZKHnn8LQ7ZrT8x2xDSrB/cpysXnHoQxx26MwX5IYyVlqWwiJkmtuvTE1vdHdyzDReedAA79GrBCQcMJawyYW3m7jakKxeffii77dBX"
    cB64 += "vAxGAaslsIcMtCiMcc5JB3PQsP7ss0s/2rcsUj1oK6Weedz+nHns3nRpX4hlp0EgMbaTeT7/lIMZ0r8zltoY1K8D55y4Lycdtqs23LPp0bENw3benojktpRG"
    cB64 += "2GfPHenSsbXK+uyjvvbu3IKo+r3Tdt20cd9B7fkUZIc48Yj9OOekvWjfOh9jbJbM38Tgnm05QBPw1GMPpnl+lvrp0LIgizOOP5S8rBAHSuYLTz6IQV2LOWKv"
    cB64 += "7SlQ4vrofYZw2WlHcOCu/YlI3nDYY9eh3Tj7uP0oKYhw+MHDaNW8gJDtqb/ZnHnSfhx31J7kZxuB1GOfPfpx/ulHZOpEJGfrohxOOHJPzjp1f7npQozGWA5J"
    cB64 += "v3/baf1t1f9ybWMMtjLulh/RoEdFwTUi4X3soGXX5YSjDuShmy6QC/AxVkgDZghKhAjJooRVNkpxQT4P3XMxnVqVqJ66bocgHMNTMO0pQMfEMuVChDWotgbI"
    cB64 += "aKAtjFFZwCdK2ESJyZZExDdkLGyj9vQ9cONhjNxfCFty4kXw/ajajmLpOWJUQ67CVhshwkT8MGFf5S0yPAI+lmVhjCFifJEaNLbqhrGJZK4h8Qjrm4oQlA0D"
    cB64 += "WWRLmrDqOZx/6h4cfcjuKp8WEMFSwaBcMOnCeFj4mJCt/tr46m8Q9HtWTAVD2Hrvy9p4ks9I7pDajGbas7EtC0u8dKKSZKlc2Oid9GH8bPU3TJax9S2stnOk"
    cB64 += "g5h6aIn0zoQkm8kQf+Nh/Y31/6rqnvHwjP8rIcFDhJTZP2CP7TjuoCHkhF2Cw1fHfCxcacWzPHyVUcaQjnKdvbu2JhQUwmjgVMoDFcmQwYegDb1wZYV8tcWf"
    cB64 += "HJ4VtO2opvPrW4OndhwTxpV6fbXnWnoX1BMfk2nXw9O9a9AVjOIg9N7P8FJZ1fN+Iw0UAp9RXGYUFviS1MvUC9oNCDJtqH+uyEfPIk/tGs9lryG9aNuqGB9H"
    cB64 += "pG8CgiPZfMmI+AT36MaSWbF8oz5bGF2N72E8R6V0DWpKXk/lg774ks1ocmRIuwXBNdCLZzl4snrBnyIF/UP98o2HZySVvhGQ7n1xZRsd1jbi8xfZqN9SEX8g"
    cB64 += "XwrxNRghJXdsS/M0GCQpXOpVIX9LuUCJmTsLozJhVM729f1Xbr9eMkXYcpigjhK1RmX5k8MKqumdr8FTEQIKqtvBoKGPIpOh3yoFX8mwDu4CCpTuZ9789j54"
    cB64 += "2kLB4Af11SUC3r89B/V+I3QE7wPKsJFQIbWPHdWjJesBxs6SlLriy8qgI+BqZe4DPioIxs/Qlmd9l270IvMJHcF7vSUo56vsnxI6jITcQkZ1jN5Iv7/e+Wp9"
    cB64 += "C+n1NjytbcjrL7AKOvMb/Vbst+ffrr+9R11Gx2/vg6sef30b3JG5D97/VzKZb/w/h9Hzn5IedQZvdMmcf7wP7v5IwV2mQIZv8BTQljd/+Tco9xttKflfn4L3"
    cB64 += "ervl1INu9PvXn0H5/5fISMp/e/yxrMmUMir1P5E+baPz7wSybSTtf9j8S2rgPyD7lxy2fy2h/wOyf63x+peU9j8g+5cctn8tof8Dsn+t8fqXlPb/AwAA//8m"
    cB64 += "sb7LAAAABklEQVQDAMg+7ZVA2493AAAAAElFTkSuQmCC"
Return cB64
