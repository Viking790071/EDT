#Region Public

// It is called to get subsystem settings.
//
// Parameters:
//  Settings - Structure - with the following properties:
//   * Attributes - Mapping - to override the names of object attribute names that contain 
//                                information about the amount and currency displayed in the list of related documents.
//                                In the key specify full name of metadata object. In the value 
//                                specify mapping between Currency and DocumentAmount attributes and actual object attributes.
//                                If it is not set, values are read from Currency and DocumentAmount attributes.
//   * AttributesForPresentation - Mapping - to override the presentation of objects displayed in 
//                                the list of related documents. In the key, specify a full metadata 
//                                object name. In the value, specify an array containing names of attributes whose values are used in presentation.
//                                To generate a presentation of listed objects the 
//                                SubordinationStructureOverridable.OnGettingPresentation procedure will be called.
//
// Example:
//	Attributes = New Map;
//	Attributes.Insert("DocumentAmount", Metadata.Documents.CustomerInvoice.Attributes.PaymentTotal.Name);
//	Attributes.Insert("Currency", Metadata.Documents.CustomerInvoice.Attributes.DocumentCurrency.Name);
//	Settings.Attributes.Insert(Metadata.Documents.CustomerInvoice.FullName(), Attributes);
//		
//	AttributesForPresentation = New Array;
//	AttributesForPresentation.Add(Metadata.Documents.OutgoingEmail.Attributes.SentDate.Name);
//	AttributesForPresentation.Add(Metadata.Documents.OutgoingEmail.Attributes.MailSubject.Name);
//	AttributesForPresentation.Add(Metadata.Documents.OutgoingEmail.Attributes.EmailRecipientList.Name);
//	Settings.AttributesForPresentation.Insert(Metadata.Documents.OutgoingEmail.FullName()
//		AttributesForPresentation);
//
Procedure OnDefineSettings(Settings) Export
	
	 For each Document In Metadata.Documents Do
		
		If Document.Attributes.Find("DocumentCurrency") <> Undefined Then
			
			Attributes = New Map;
			Attributes.Insert("Currency", "DocumentCurrency");
			Settings.Attributes.Insert(Document.FullName(), Attributes);
			
		ElsIf Document.Attributes.Find("CashCurrency") <> Undefined Then
			
			Attributes = New Map;
			Attributes.Insert("Currency", "CashCurrency");
			Settings.Attributes.Insert(Document.FullName(), Attributes);
			
		EndIf;
		
	EndDo;
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.TransferAndPromotion.Attributes.OperationKind.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.TransferAndPromotion.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.PurchaseOrder.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.PurchaseOrder.Attributes.OrderState.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.PurchaseOrder.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.SalesOrder.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.SalesOrder.Attributes.OrderState.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.SalesOrder.FullName(),
		AttributesForPresentation);
		
	// begin Drive.FullVersion
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.ProductionOrder.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.ProductionOrder.Attributes.OrderState.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.ProductionOrder.FullName(),
		AttributesForPresentation);
	// end Drive.FullVersion
	
	// begin Drive.FullVersion
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.EmployeeTask.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.EmployeeTask.Attributes.State.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.EmployeeTask.FullName(),
		AttributesForPresentation);
	// end Drive.FullVersion
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.ExpenseReport.Attributes.Employee.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.ExpenseReport.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.ProductReturn.Attributes.CashCR.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.ProductReturn.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.SalesSlip.Attributes.CashCR.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.SalesSlip.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.Event.Attributes.EventType.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.Event.FullName(),
		AttributesForPresentation);
		
	// begin Drive.FullVersion
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.JobSheet.Attributes.Performer.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.JobSheet.FullName(),
		AttributesForPresentation);
	// end Drive.FullVersion
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.ReconciliationStatement.Attributes.Status.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.ReconciliationStatement.FullName(),
		AttributesForPresentation);
		
	// begin Drive.FullVersion
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.Production.Attributes.OperationKind.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.Production.FullName(),
		AttributesForPresentation);
	// end Drive.FullVersion
		
	// begin Drive.FullVersion
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.Manufacturing.Attributes.OperationKind.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.Manufacturing.FullName(),
		AttributesForPresentation);
	// end Drive.FullVersion
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.PaymentExpense.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.PaymentExpense.Attributes.BankAccount.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.PaymentExpense.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.CashVoucher.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.CashVoucher.Attributes.PettyCash.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.CashVoucher.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.PaymentReceipt.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.PaymentReceipt.Attributes.BankAccount.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.PaymentReceipt.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.CashReceipt.Attributes.OperationKind.Name);
	AttributesForPresentation.Add(Metadata.Documents.CashReceipt.Attributes.PettyCash.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.CashReceipt.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.PayrollSheet.Attributes.OperationKind.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.PayrollSheet.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.IntraWarehouseTransfer.Attributes.OperationKind.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.IntraWarehouseTransfer.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.InventoryTransfer.Attributes.OperationKind.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.InventoryTransfer.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.ShiftClosure.Attributes.CashCR.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.ShiftClosure.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.AccountSalesToConsignor.Attributes.Counterparty.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.AccountSalesToConsignor.FullName(),
		AttributesForPresentation);
	
	AttributesForPresentation = New Array;
	AttributesForPresentation.Add(Metadata.Documents.AccountSalesFromConsignee.Attributes.Counterparty.Name);
	Settings.AttributesForPresentation.Insert(Metadata.Documents.AccountSalesFromConsignee.FullName(),
		AttributesForPresentation);
		
EndProcedure

// It is called to get presentation of objects displayed in the list of related documents.
// Only for the objects listed in the AttributesForPresentation property of the Settings parameter 
// of the SubordinationStructureOverridable.OnDefineSettings procedure.
//
// Parameters:
//  DataType - AnyRef - reference type of the displayed object. See the Filter criteria type RelatedDocuments property.
//  Data - QueryResultSelection, Structure - contains the values of the fields from which presentation is generated:
//               * Reference - AnyRef - reference of the object displayed in the list of related documents.
//               * AdditionalAttribute1 - Arbitrary - value of the first attribute specified in the array.
//                 AttributesForPresentation Settings parameter of the OnDefineSettings procedure.
//               * AdditionalAttribute2 - Arbitrary - value of the second attribute...
//               ...
//  Presentation - Row - return the calculated object presentation in this parameter.
//  StandardProcessing - Boolean - if value of Presentation parameter is set, return False to this parameter.
//
Procedure OnGettingPresentation(DataType, Data, Presentation, StandardProcessing) Export
	
	StandardProcessing = False;
	
	Presentation = Data.Presentation;
	
	If (Data.DocumentAmount <> 0) AND (Data.DocumentAmount <> NULL) Then
		
		Presentation = Presentation + " " + NStr("en = 'Total'; ru = 'Всего';pl = 'Razem';es_ES = 'Total';es_CO = 'Total';tr = 'Toplam';it = 'Totale';de = 'Gesamt'") + " " + Data.DocumentAmount;
		
		If ValueIsFilled(Data.Currency) AND (Data.Currency <> NULL) Then
			
			Presentation = Presentation + " " + Data.Currency;
			
		ElsIf DataType = Type("DocumentRef.Stocktaking")
			OR DataType = Type("DocumentRef.InventoryIncrease")
			OR DataType = Type("DocumentRef.OtherExpenses")
			OR DataType = Type("DocumentRef.InventoryWriteOff") Then
			
			RefCompany = Common.ObjectAttributeValue(Data.Ref, "Company");
			
			Presentation = Presentation + " " + DriveServer.GetPresentationCurrency(RefCompany);
			
		// begin Drive.FullVersion
		ElsIf DataType = Type("DocumentRef.EmployeeTask") Then
			
			PriceKind = Common.ObjectAttributeValue(Data.Ref, "PriceKind");
			If ValueIsFilled(PriceKind) Then
				
				Presentation = Presentation + " " + Common.ObjectAttributeValue(PriceKind, "PriceCurrency");
				
			EndIf;
		// end Drive.FullVersion	
		
		EndIf;
		
	EndIf;
	
	For IndexOfAdditionalAttribute = 1 To 3 Do
		
		AdditionalValue = Data["AdditionalAttribute" + String(IndexOfAdditionalAttribute)];
		
		If ValueIsFilled(AdditionalValue) Then
			
			Presentation = Presentation + ", " + TrimAll(AdditionalValue);
			
		EndIf;
		
	EndDo;
	
EndProcedure	
	
#Region ObsoleteProceduresAndFunctions

// Obsolete. Use the SubordinationStructureOverridable.OnDefineSettings.
// See AttributesForPresentation property of the Settings parameter.
// Generates an array of document attributes.
// 
// Parameters:
//  DocumentName - Row - document name.
//
// Returns:
//   Array - an array of document attribute descriptions.
//
Function ObjectAttributesArrayForPresentationGeneration(DocumentName) Export
	
	Return New Array;
	
EndFunction

// Obsolete. Use the SubordinationStructureOverridable.OnGettingPresentation.
// Gets document presentation for printing.
//
// Parameters:
//  Selection  - DataCollection - structure or selection from the query results which contains 
//                 additional attributes based on which you can generate overridden document 
//                 presentation for output to the "Subordination structure" report.
//                 
//
// Returns:
//   Row,Undefined - overridden document presentation or Undefined, if it is not specified for this 
//                           document type.
//
Function ObjectPresentationForReportOutput(Selection) Export
	
	Return Undefined;
	
EndFunction

// Obsolete. Use the SubordinationStructureOverridable.OnDefineSettings.
// See Attributes property of the Settings parameter.
// Returns the name of the document attribute that contains information about Amount and Currency of 
// the document for output to the subordination structure.
// The default attributes are Currency and DocumentAmount. If other attributes are used for a 
// particular document or configuration, you can override the default values in this function.
// 
//
// Parameters:
//  DocumentName - Row - name of the document whose attribute name is required.
//  Attribute - Row - row values can be "Currency" and "DocumentAmount".
//
// Returns:
//   Row - name of document attribute that contains information about Currency or Amount.
//
Function DocumentAttributeName(DocumentName, Attribute) Export
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion
