#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Procedure inserts the text which is passed as a parameter to the tabular document field.
// 
Procedure InsertTextInFormula(Indicator)
	
	FormulaText = FormulaText + " [" + TrimAll(Indicator) + "] ";
			
EndProcedure

&AtServerNoContext
// Function receives the indicator ID.
//
Function GetIndicatorID(DataStructure)
	
	Return TrimAll(DataStructure.SelectedRow.ID);

EndFunction

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TextIndicators = NStr("en = 'To add an indicator to the formula, double-click it'; ru = 'Для размещения показателя в формуле дважды щелкните левой кнопкой мыши';pl = 'Aby dodać wskaźnik do formuły, kliknij ją dwukrotnie';es_ES = 'Para añadir un indicador a la fórmula, hacer el doble clic en ella';es_CO = 'Para añadir un indicador a la fórmula, hacer el doble clic en ella';tr = 'Formüle gösterge eklemek için çift tıklayın';it = 'Per posizionare l''indicatore nella formula, fare doppio clic su di esso';de = 'Um zu der Formel einen Indikator hinzuzufügen, doppelklicken Sie darauf'");
	
	If Parameters.Property("FormulaText") Then
		
		FormulaText = Parameters.FormulaText;
		
	EndIf;	
	
EndProcedure

#Region FormButtonItemEventHandlers

&AtClient
// Procedure - button click handler OK
//
Procedure CommandOK(Command)
	
	Close(FormulaText);
	
EndProcedure

#EndRegion

#Region DynamicListEventHandlersCalculationParameters

&AtClient
// Procedure - event handler Selection of dynamic list ProductParameters.
//
Procedure EarningsCalculationParametersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	DataStructure = New Structure("SelectedRow", SelectedRow);
	
	TextInFormula = GetIndicatorID(DataStructure);
    InsertTextInFormula(TextInFormula);

EndProcedure

#EndRegion

#EndRegion
