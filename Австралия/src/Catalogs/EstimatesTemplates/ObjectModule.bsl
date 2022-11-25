#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PresentationCurrency = GetFunctionalOption("ForeignExchangeAccounting");
	AccountCurrency = DriveReUse.GetFunctionalCurrency();
	Errors = Undefined;
	
	For Each Line In Expenses Do
		If Line.CalculationMethod = Enums.CostsAmountCalculationMethods.FixedAmount AND Not ValueIsFilled(Line.Currency) Then
			If PresentationCurrency Then
				LineIndex = Expenses.IndexOf(Line);
				CommonClientServer.AddUserError(
					Errors, 
					"Expenses.Currency",,
					"Expenses.Currency",
					LineIndex,
					NStr("en = 'Not specified currency in line %1'; ru = 'Не указана валюта в строке %1';pl = 'Nie określono waluty w wierszu %1';es_ES = 'Moneda no especificada en la línea %1';es_CO = 'Moneda no especificada en la línea %1';tr = '%1 satırında para birimi belirtilmedi';it = 'Non specificata la valuta nella riga %1';de = 'Nicht angegebene Währung in der Zeile %1'"),
					LineIndex);
			Else
				Line.Currency = AccountCurrency;
			EndIf; 
		EndIf; 
	EndDo;
	
	If Not Errors = Undefined Then
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	EndIf; 
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	// Update requisite ConnectionKey
	
	ConnectionKey = 0;
	For Each Line In Inventory Do
		ConnectionKey = Max(ConnectionKey, Line.ConnectionKey); 
	EndDo; 
	For Each Line In Expenses Do
		ConnectionKey = Max(ConnectionKey, Line.ConnectionKey); 
	EndDo;
	
	For Each Line In Inventory Do
		If Line.ConnectionKey=0 Then
			ConnectionKey = ConnectionKey + 1;
			Line.ConnectionKey = ConnectionKey;
		EndIf; 
	EndDo; 
	For Each Line In Expenses Do
		If Line.ConnectionKey = 0 Then
			ConnectionKey = ConnectionKey + 1;
			Line.ConnectionKey = ConnectionKey;
		EndIf; 
	EndDo; 
	
EndProcedure

#EndRegion

#EndIf