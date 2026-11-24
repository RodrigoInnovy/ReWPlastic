#include "totvs.ch"

/*/{Protheus.doc} MA650BUT
Ponto de Entrada para adicionar opcoes no menu principal (aRotina / Outras Acoes) do browse da rotina MATA650.
@type user function
@author Arquiteto Protheus
@since 23/11/2026
@version 12.1.2410
@return array, Array aRotina atualizado com a opcao de impressao grafica da OP
@see http://tdn.totvs.com/display/public/mp/MA650BUT+-+Adiciona+itens+no+menu+principal+do+fonte+MATA650
/*/
User Function MA650BUT()
    Local aArea := GetArea()

    // No MATA650, o PE MA650BUT adiciona itens ao array Private aRotina (Menu do FWMBrowse):
    // Estrutura esperada pelo FWFormBrowse:AddButton:
    // [1] Titulo (C), [2] Rotina (C), [3] Reservado (N = 0), [4] Tipo de Operacao (N = 2 ou 6)
    If Type("aRotina") == "A"
        aAdd(aRotina, {"Imprimir OP (Gráfico)", "U_RELPCP01(.T.)", 0, 2})
    EndIf

    RestArea(aArea)
Return aRotina
