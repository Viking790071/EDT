#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And Parameters.Property("GLExpenseAccount") Then
		
		If ValueIsFilled(Parameters.GLExpenseAccount) Then
			
			If Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
				And Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
				And Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
				
				MessageText = NStr("en = 'Business area is not specified for this account type.'; ru = 'Для данного типа счета направление деятельности не указывается!';pl = 'Dla tego typu konta nie określono kierunku działalności.';es_ES = 'Área de negocio no está especificada para este tipo de cuenta.';es_CO = 'Área de negocio no está especificada para este tipo de cuenta.';tr = 'Bu hesap türü için iş alanı belirlenmedi.';it = 'Settore di attività non è specificato per questo tipo di conto.';de = 'Der Geschäftsbereich wurde für diesen Kontotyp nicht angegeben.'");
				DriveServer.ShowMessageAboutError(, MessageText, , , , Cancel);
				
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'Account is not selected.'; ru = 'Не выбран счет!';pl = 'Konto nie zostało wybrane.';es_ES = 'Cuenta no está seleccionada.';es_CO = 'Cuenta no está seleccionada.';tr = 'Hesap seçilmedi.';it = 'Il conto non è selezionato.';de = 'Konto ist nicht ausgewählt.'");
			DriveServer.ShowMessageAboutError(, MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
