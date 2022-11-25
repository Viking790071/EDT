
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		If Object.Ref.IsEmpty() Then
			Cancel = True;
		EndIf;
		Return;
	EndIf;
	
	If TypeOf(Parameters.Basis) = Type("DocumentRef.CreditNote") Then
		If Parameters.Basis.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = '%1 is not subject to VAT.'; ru = '%1 не облагается НДС.';pl = '%1 nie podlega VAT.';es_ES = '%1 no está sujeto al IVA.';es_CO = '%1 no está sujeto al IVA.';tr = '%1 KDV''ye tabi değil.';it = '%1 non è soggetta ad IVA.';de = '%1 ist nicht umsatzsteuerpflichtig.'"),
							Parameters.Basis);
			CommonClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.DateOfSupply = ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate());
		OnReadCreateAtServer();
	EndIf;
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	OnReadCreateAtServer();
	FillDocumentAmounts();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If UsersClientServer.IsExternalUserSession() Then
		PrintManagementClientDrive.GeneratePrintFormForExternalUsers(Object.Ref,
			"Document.TaxInvoiceIssued",
			"TaxInvoice",
			NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura de impuestos';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'"),
			FormOwner,
			UniqueKey);
		Cancel = True;
		Return;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	If Not ValueIsFilled(Object.Ref) Then
		AutoTitle = False;
		Title = SetTitle(Object);
	EndIf;
	
	ManageFormItems();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Cancel Then
		Return;
	EndIf;
	
	MessageText = NStr("en = 'Attribute ""Date of supply"" is empty'; ru = 'Поле ""Дата выставления"" не заполнено';pl = 'Atrybut ""Data dostawy"" jest pusty';es_ES = 'Atributo ""Fecha de suministro"" está vacío';es_CO = 'Atributo ""Fecha de suministro"" está vacío';tr = '""Tedarik tarihi"" özniteliği boş';it = 'Il campo ""Data di della fornitura"" non è compilato';de = 'Attribut ""Lieferdatum"" ist leer'");
	
	If DateOfSupplyCheckbox AND NOT ValueIsFilled(Object.DateOfSupply) Then
		CommonClientServer.MessageToUser(MessageText,, "DateOfSupply", "Object", Cancel);
	ElsIf NOT DateOfSupplyCheckbox Then
		Object.DateOfSupply = '00010101'; 	
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "TaxInvoiceIssued");
	// End StandardSubsystems.Interactions
	
	AutoTitle = True;
	Title = "";
	
	WorkWithVATClient.AfterWriteTaxInvoice(ThisForm, FormOwner, Object);
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Read();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure BasisDocumentStartChoiceEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Posted", True);
	VATTaxationArray = New Array;
	VATTaxationArray.Add(PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT"));
	VATTaxationArray.Add(PredefinedValue("Enum.VATTaxationTypes.ForExport"));
	
	Filter.Insert("VATTaxation", VATTaxationArray);
	
	If SelectedElement.Value = "CreditNote" Then
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.SalesReturn") Then
			
			Filter.Insert("OperationKind", PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn"));
			
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.Adjustments") Then	
			
			OperationKindArray = New Array;
			OperationKindArray.Add(PredefinedValue("Enum.OperationTypesCreditNote.Adjustments"));
			OperationKindArray.Add(PredefinedValue("Enum.OperationTypesCreditNote.DiscountAllowed"));
			
			Filter.Insert("OperationKind", OperationKindArray);
			
		EndIf;
	EndIf;
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("Filter", Filter);
	
	OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,AdditionalParameters.Item);
		
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	ManageFormItems();
	ClearBasisDocuments();
	WorkWithVATServerCall.CheckForTaxInvoiceUse(?(DateOfSupplyCheckbox, Object.DateOfSupply, Object.Date), Object.Company);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	ManageFormItems();
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure CounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.Counterparties.ChoiceForm", New Structure("Filter, ChoiceMode, CloseOnChoice", New Structure("Customer", True), True, True), Item);

EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure DateOfSupplyCheckboxOnChange(Item)
	
	ManageFormItems();
	
EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.BasisDocuments.CurrentData;
	
	StructureFilter = New Structure("Counterparty, Company, Currency",
		Object.Counterparty, Object.Company, Object.Currency);
		
	ParameterStructure = New Structure("Filter, DocumentType", StructureFilter, TypeOf(Object.Ref));
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment") Then
		ParameterStructure.Insert("ThisIsAdvancePaymentsIssued", True);
	Else
		ParameterStructure.Insert("ThisIsTaxInvoiceIssued", True);
	EndIf;
	
	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);

EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array") Then  
		
		StandardProcessing = False;
		CurrentData = Items.BasisDocuments.CurrentData;
		CurrentData.BasisDocument = Undefined;
		
		For Each ArrayItem In SelectedValue Do
			FilterParameters = New Structure;
			FilterParameters.Insert("BasisDocument",ArrayItem);
			If Not IsDuplicatingInvoice(ArrayItem) Then
				If ValueIsFilled(CurrentData.BasisDocument) Then 
					RowBasisDocuments = Object.BasisDocuments.Add();
					RowBasisDocuments.BasisDocument = ArrayItem;
				Else 
					CurrentData.BasisDocument = ArrayItem;
				EndIf;
			EndIf;
		EndDo;
		
		FillDocumentAmounts();
		
	Else
		
		StandardProcessing = False;
		CurrentData = Items.BasisDocuments.CurrentData;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("BasisDocument", SelectedValue.Document);
		
		If Not IsDuplicatingInvoice(SelectedValue.Document) Then
			CurrentData.BasisDocument = SelectedValue.Document;
		EndIf;
		
		FillDocumentAmounts();
		
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure DateOfSupplyOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment") Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(Object.DateOfSupply, Object.Company);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(Object.DateOfSupply, Object.Company);
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	Object.BasisDocuments.Clear();
	
	AutoTitle = False;
	Title = SetTitle(Object);
	
EndProcedure

&AtClient
Procedure BasisDocumentsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Clone Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SetTitle(Val Object)
	
	Title = "";
	
	If ValueIsFilled(Object.Ref) Then
		Documents.TaxInvoiceIssued.PresentationGetProcessing(Object, Title, False, Object.OperationKind);
	Else
		Title = Documents.TaxInvoiceIssued.GetTitle(Object.OperationKind, True);
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

#Region Other

&AtClient
Procedure ManageFormItems()
	
	IsNew				= NOT ValueIsFilled(Object.Ref);
	IsReadOnly			= DateOfSupplyCheckbox AND NOT IsNew;
	
	Items.DateOfSupply.Enabled		= DateOfSupplyCheckbox;
	Items.Number.ReadOnly			= IsReadOnly; 
	Items.Company.ReadOnly			= IsReadOnly;
	Items.Counterparty.ReadOnly		= IsReadOnly;
	Items.Currency.ReadOnly			= IsReadOnly;
	Items.BasisDocuments.ReadOnly	= Not ValueIsFilled(Object.Counterparty);
	
EndProcedure

&AtClient
Procedure ClearBasisDocuments()
	
	Object.BasisDocuments.Clear();

EndProcedure

&AtServer
Procedure OnReadCreateAtServer()
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	DateOfSupplyCheckbox = ValueIsFilled(Object.DateOfSupply);
	
EndProcedure

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

#EndRegion

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
				Invoice));
		Return True;
	EndIf;
	
EndFunction

&AtServer
Procedure FillDocumentAmounts()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Payment.Ref AS BasisDocument,
		|	Payment.VATAmount AS VATAmount,
		|	Payment.PaymentAmount AS Amount
		|INTO BasisDocuments
		|FROM
		|	Document.CashReceipt.PaymentDetails AS Payment
		|WHERE
		|	Payment.Ref IN(&Documents)
		|	AND Payment.AdvanceFlag
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Ref,
		|	Payment.VATAmount,
		|	Payment.PaymentAmount
		|FROM
		|	Document.PaymentReceipt.PaymentDetails AS Payment
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
		|	SalesInvoiceInventory.Ref AS BasisDocument,
		|	SalesInvoiceInventory.VATAmount AS VATAmount,
		|	SalesInvoiceInventory.Total AS Amount
		|INTO BasisDocuments
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	CreditNote.Ref,
		|	CreditNote.VATAmount,
		|	CreditNote.DocumentAmount
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Ref IN(&Documents)
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
		
	EndIf;
	
	Query.SetParameter("Documents", Object.BasisDocuments.Unload(,"BasisDocument"));
	
	Selection = Query.Execute().Select();
	DocObject = FormAttributeToValue("Object");
	
	While Selection.Next() Do
		RowBasisDocuments = DocObject.BasisDocuments.Find(Selection.BasisDocument,"BasisDocument");
		FillPropertyValues(RowBasisDocuments, Selection);
	EndDo;
	
	ValueToFormAttribute(DocObject,"Object");
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	If Not DateOfSupplyCheckbox Then
		CheckForTaxInvoiceUse();
	EndIf;
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure CheckForTaxInvoiceUse()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
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
