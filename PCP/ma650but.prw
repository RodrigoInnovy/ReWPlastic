#include "totvs.ch"

/*/{Protheus.doc} MA650BUT
Ponto de Entrada para adicionar botão de impressão gráfica da OP no browse/tela do MATA650.
@type user function
@author Arquiteto Protheus
@since 23/11/2026
@return array, Array de botões atualizado
/*/
User Function MA650BUT()
    Local aButtons := {}

    If ValType(PARAMIXB) == "A"
        aButtons := aClone(PARAMIXB)
    EndIf

    aAdd(aButtons, {"IMPRESSAO", {|| U_RELPCP01(.T.) }, "Imprimir OP (Gráfico)", "Imprimir OP"})
Return aButtons
