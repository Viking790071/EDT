#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	If Not ValueIsFilled(Object.Ref) Then
		Title = SetTitle(Object);
		AutoTitle = False;
	EndIf;
	
	ManageFormItems();
	
	RecalculateSubtotal();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	FillDocumentAmounts();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = SetTitle(Object);
	AutoTitle = False;
	WorkWithVATClient.AfterWriteTaxInvoice(ThisForm, FormOwner, Object);
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Read();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure CounterpartyOnChange(Item)
	
	ManageFormItems();
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	ClearBasisDocuments();
	WorkWithVATServerCall.CheckForTaxInvoiceUse(Object.DateOfSupply, Object.Company);
	
EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.BasisDocuments.CurrentData;
	
	StructureFilter = New Structure("Counterparty, Company, Currency",
		Object.Counterparty, Object.Company, Object.Currency);
		
	ParameterStructure = New Structure("Filter, DocumentType", StructureFilter, TypeOf(Object.Ref));
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
		ParameterStructure.Insert("ThisIsAdvancePaymentsReceived", True);
	Else
		ParameterStructure.Insert("ThisIsTaxInvoiceReceived", True);
	EndIf;
	
	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.BasisDocuments.CurrentData;
		
	FilterParameters = New Structure("BasisDocument", SelectedValue.Document);
	
	If Not IsDuplicatingInvoice(SelectedValue.Document) Then
		CurrentData.BasisDocument = SelectedValue.Document;
	EndIf;
	
	FillDocumentAmounts();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure CounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;	
	OpenForm("Catalog.Counterparties.ChoiceForm", New Structure("Filter, ChoiceMode, CloseOnChoice", New Structure("Supplier", True), True, True), Item);
	
EndProcedure

&AtClient
Procedure DateOfSupplyOnChange(Item)
	
	CheckForTaxInvoiceUse();
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	Object.BasisDocuments.Clear();
	
	Title = SetTitle(Object);
	AutoTitle = False;
EndProcedure

&AtServerNoContext
Function SetTitle(Val Object)
	
	Title = "";
	
	If ValueIsFilled(Object.Ref) Then
		Documents.TaxInvoiceReceived.PresentationGetProcessing(Object, Title, False, Object.OperationKind);
	Else
		Title = Documents.TaxInvoiceReceived.GetTitle(Object.OperationKind, True);
	EndIf;
		
	Return Title;
EndFunction

&AtClient
Procedure BasisDocumentsOnChange(Item)
	RecalculateSubtotal();
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

&AtClient
Function IsDuplicatingInvoice(Invoice)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("BasisDocument",Invoice);
	
	If Object.BasisDocuments.FindRows(FilterParameters).Count() = 0 Then
		Return False;
	Else
		
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The document %1 already exists in the list.'; ru = 'Документ %1 уже присутствует в списке.';pl = 'Dokument %1 jest już na liście.';es_ES = 'El documento %1 ya existe en la lista.';es_CO = 'El documento %1 ya existe en la lista.';tr = '%1 belgesi listede zaten var.';it = 'Il documento %1 esiste già nell''elenco.';de = 'Das Dokument %1 existiert bereits in der Liste.'"),
				Invoice
			)
		);
		
		Return True;
		
	EndIf;
	
EndFunction

&AtServer
Procedure FillDocumentAmounts()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Payment.Ref AS BasisDocument,
		|	Payment.VATAmount AS VATAmount,
		|	Payment.PaymentAmount AS Amount
		|INTO BasisDocuments
		|FROM
		|	Document.CashVoucher.PaymentDetails AS Payment
		|WHERE
		|	Payment.Ref IN(&Documents)
		|	AND Payment.AdvanceFlag
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Ref AS BasisDocument,
		|	Payment.VATAmount AS VATAmount,
		|	Payment.PaymentAmount AS Amount
		|FROM
		|	Document.PaymentExpense.PaymentDetails AS Payment
		|WHERE
		|	Payment.Ref IN(&Documents)
		|	AND Payment.AdvanceFlag
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BasisDocuments.BasisDocument AS BasisDocument,
		|	SUM(BasisDocuments.VATAmount) AS VATAmount,
		|	SUM(BasisDocuments.Amount) AS Amount
		|FROM
		|	BasisDocuments AS BasisDocuments
		|
		|GROUP BY
		|	BasisDocuments.BasisDocument");
		
	Else
		
		Query = New Query("
		|SELECT ALLOWED
		|	SupplierInvoiceInventory.Ref AS BasisDocument,
		|	SupplierInvoiceInventory.VATAmount AS VATAmount,
		|	SupplierInvoiceInventory.Total AS Amount
		|INTO DocumentData
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceExpenses.Ref,
		|	SupplierInvoiceExpenses.VATAmount,
		|	SupplierInvoiceExpenses.Total
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|WHERE
		|	SupplierInvoiceExpenses.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	SubcontractorInvoiceReceivedProducts.Ref,
		|	SubcontractorInvoiceReceivedProducts.VATAmount,
		|	SubcontractorInvoiceReceivedProducts.Total
		|FROM
		|	Document.SubcontractorInvoiceReceived.Products AS SubcontractorInvoiceReceivedProducts
		|WHERE
		|	SubcontractorInvoiceReceivedProducts.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	ExpenseReportInventory.Ref,
		|	ExpenseReportInventory.VATAmount,
		|	ExpenseReportInventory.Total
		|FROM
		|	Document.ExpenseReport.Inventory AS ExpenseReportInventory
		|WHERE
		|	ExpenseReportInventory.Ref IN(&Documents)
		|	AND ExpenseReportInventory.DeductibleTax
		|	AND ExpenseReportInventory.Supplier = &Counterparty
		|
		|UNION ALL
		|
		|SELECT
		|	ExpenseReportExpenses.Ref,
		|	ExpenseReportExpenses.VATAmount,
		|	ExpenseReportExpenses.Total
		|FROM
		|	Document.ExpenseReport.Expenses AS ExpenseReportExpenses
		|WHERE
		|	ExpenseReportExpenses.Ref IN(&Documents)
		|	AND ExpenseReportExpenses.DeductibleTax
		|	AND ExpenseReportExpenses.Supplier = &Counterparty
		|
		|UNION ALL
		|
		|SELECT
		|	DebitNote.Ref,
		|	DebitNote.VATAmount,
		|	DebitNote.DocumentAmount
		|FROM
		|	Document.DebitNote AS DebitNote
		|WHERE
		|	DebitNote.Ref IN(&Documents)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentData.BasisDocument AS BasisDocument,
		|	SUM(DocumentData.VATAmount) AS VATAmount,
		|	SUM(DocumentData.Amount) AS Amount
		|FROM
		|	DocumentData AS DocumentData
		|
		|GROUP BY
		|	DocumentData.BasisDocument");
		
	EndIf;
	
	Query.SetParameter("Documents", Object.BasisDocuments.Unload(, "BasisDocument"));
	Query.SetParameter("Counterparty", Object.Counterparty);
	
	Selection = Query.Execute().Select();
	DocObject = FormAttributeToValue("Object");
	
	While Selection.Next() Do
		RowBasisDocuments = DocObject.BasisDocuments.Find(Selection.BasisDocument, "BasisDocument");
		FillPropertyValues(RowBasisDocuments, Selection);
	EndDo;
	
	ValueToFormAttribute(DocObject, "Object");
	
EndProcedure

&AtClient
Procedure ClearBasisDocuments()
	
	Object.BasisDocuments.Clear();

EndProcedure

&AtClient
Procedure ManageFormItems()
	
	Items.BasisDocuments.ReadOnly = Not ValueIsFilled(Object.Counterparty);

EndProcedure

&AtServer
Procedure CheckForTaxInvoiceUse()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(Object.DateOfSupply, Object.Company);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(Object.DateOfSupply, Object.Company);
	EndIf;
	
EndProcedure

// Procedure recalculates subtotal
//
&AtClient
Procedure RecalculateSubtotal()
	
	AmountTotal = Object.BasisDocuments.Total("Amount");
	VATAmountTotal = Object.BasisDocuments.Total("VATAmount");
	
	Object.DocumentAmount = AmountTotal;
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal;
	
EndProcedure

#EndRegion
