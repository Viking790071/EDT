#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	OrderState = GetSubcontractorOrderReceivedState();
	Closed = False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	If Not ValueIsFilled(OrderState) Then
		OrderState = GetSubcontractorOrderReceivedState();
	EndIf;
	
	If Not ValueIsFilled(DateRequired) Then
		DateRequired = CurrentSessionDate();
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("SubcontractorOrderReceivedStatuses", "Completed") Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 is completed. Editing is restricted.'; ru = '%1 выполнен. Редактирование запрещено.';pl = '%1 jest zakończony. Edycja jest ograniczona.';es_ES = '%1 ha sido completado. La edición está restringida.';es_CO = '%1 ha sido completado. La edición está restringida.';tr = '%1 tamamlandı. Düzenleme kısıtlı.';it = '%1 è stato completato. La modifica è limitata.';de = '%1 ist abgeschlossen. Bearbeitung ist eingeschränkt.'"), Ref);
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	DocumentAmount = Products.Total("Total");
	DocumentTax = Products.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.SubcontractorOrderReceived.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractorOrdersReceived(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.SubcontractorOrderReceived.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.SubcontractorOrderReceived.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not Constants.UseSubcontractorOrderReceivedStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'With the current settings, the order status fields are required.'; ru = 'При текущих настройках необходимо заполнить поля статуса заказа.';pl = 'Z bieżącymi ustawieniami, pola statusu zamówienia są wymagane.';es_ES = 'Con la configuración actual, los campos de estado de la orden son obligatorios.';es_CO = 'Con la configuración actual, los campos de estado de la orden son obligatorios.';tr = 'Mevcut ayarlarda sipariş durumu alanları gerekli.';it = 'Con le impostazioni correnti sono richiesti i campi di stato dell''ordine.';de = 'Bei den aktuellen Einstellungen sind die Auftrag-Statusfelder erforderlich.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	//Cash flow projection
	Amount = Products.Total("Amount");
	VATAmount = Products.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

#EndRegion

#Region Internal

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification() Export
	
	TableComponents = Catalogs.BillsOfMaterials.GetBOMComponentsIncludingNestedLevels(Products.Unload());
	
	Inventory.Load(TableComponents);
	
EndProcedure

#EndRegion

#Region Private

Function GetSubcontractorOrderReceivedState()
	
	If Constants.UseSubcontractorOrderReceivedStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSubcontractorOrderReceived");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.SubcontractorOrderReceivedStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.SubcontractorOrderReceivedInProgressStatus.Get();
	EndIf;
	
	Return OrderState;
	
EndFunction

#EndRegion

#EndIf