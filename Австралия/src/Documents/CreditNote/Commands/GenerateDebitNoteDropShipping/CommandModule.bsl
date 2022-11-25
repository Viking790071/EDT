#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If EverythingFromCreditNoteIsAlreadyReturned(CommandParameter) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'For ""%1"", the return of all drop shipping products has already been recorded.'; ru = 'Для ""%1"" уже зарегистрирован возврат всех товаров для дропшиппинга.';pl = 'Dla ""%1"", zwrot wszystkich produktów dropshipping już zostały zapisane.';es_ES = 'En el caso de ""%1"", ya se ha registrado la devolución de todos los productos de envío directo.';es_CO = 'En el caso de ""%1"", ya se ha registrado la devolución de todos los productos de envío directo.';tr = '""%1"" için tüm stoksuz satış ürünlerinin iadesi zaten kaydedildi.';it = 'Per ""%1"", è stato registrato il ritorno di tutti i prodotti di dropshipping.';de = 'Für ""%1"", ist die Rückgabe von alle Produkten aus dem Streckengeschäft bereits gebucht.'"),
				CommandParameter);
		CommonClientServer.MessageToUser(MessageText, CommandParameter);
		Return;
	EndIf;
	
	Result = FindSupplierInvoices(CommandParameter);
	
	If Not Result.HaveSalesOrders Or Not Result.HaveSupplierInvoices Then
		
		FillStructure = New Structure();
		FillStructure.Insert("BasisDocument", 			CommandParameter);
		FillStructure.Insert("SupplierInvoices", 		New Array);
		FillStructure.Insert("HaveSalesOrders", 		Result.HaveSalesOrders);
		FillStructure.Insert("HaveSupplierInvoices", 	Result.HaveSupplierInvoices);
		FillStructure.Insert("IsDropShipping", 			True);
		
		OpenForm("Document.DebitNote.ObjectForm",
			New Structure("Basis", FillStructure),
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
		
	Else
		
		SupplierInvoicesMap = Result.SupplierInvoicesMap;
		CounterpartiesMap = Result.CounterpartiesMap;
		
		TryCount = 0;
		ErrorMessage = "";
		For Each Row In CounterpartiesMap Do
			FillStructure = New Structure();
			FillStructure.Insert("BasisDocument", 			CommandParameter);
			FillStructure.Insert("SupplierInvoices", 		SupplierInvoicesMap.Get(Row.Key));
			FillStructure.Insert("HaveSalesOrders", 		Result.HaveSalesOrders);
			FillStructure.Insert("HaveSupplierInvoices", 	Result.HaveSupplierInvoices);
			FillStructure.Insert("Counterparty", 			CounterpartiesMap.Get(Row.Key));
			FillStructure.Insert("Contract", 				Row.Key);
			FillStructure.Insert("IsDropShipping", 			True);
			
			Try
				OpenForm("Document.DebitNote.ObjectForm",
					New Structure("Basis", FillStructure),
					CommandExecuteParameters.Source,
					True,
					CommandExecuteParameters.Window,
					CommandExecuteParameters.URL);
			Except
				TryCount = TryCount + 1;
				ErrorMessage = ?(ErrorMessage = "", BriefErrorDescription(ErrorInfo()), ErrorMessage);
			EndTry;
			
		EndDo;
		
		If TryCount = CounterpartiesMap.Count() Then
			Raise ErrorMessage;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function EverythingFromCreditNoteIsAlreadyReturned(FillingData)
	
	FillingDataAttributes = Common.ObjectAttributesValues(FillingData, "Posted, OperationKind, Company");
	Documents.DebitNote.CheckAbilityOfEnteringByCreditNote(FillingData,
		FillingDataAttributes.Posted,
		FillingDataAttributes.OperationKind,
		FillingDataAttributes.Company);
	
	Return Documents.DebitNote.EverythingFromCreditNoteIsAlreadyReturned(FillingData, Documents.DebitNote.EmptyRef());
	
EndFunction

&AtServer
Function FindSupplierInvoices(FillingData)
	
	Return Documents.DebitNote.DropShippingSupplierInvoicesToReturn(FillingData);
	
EndFunction

#EndRegion

