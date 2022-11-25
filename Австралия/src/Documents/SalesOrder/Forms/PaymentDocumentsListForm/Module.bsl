
#Region GeneralPurposeProceduresAndFunctions

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Counterparty");
	DriveClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
	If Items.List.CurrentRow <> Undefined Then
		UpdateListOfPaymentDocuments();
	EndIf;
	
EndProcedure

// Function returns the list of the sales invoices related to the current order.
//
&AtServerNoContext
Function GetListOfLinkedDocuments(DocumentSalesOrder)
	
	ListOfShipmentDocuments = New ValueList;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubordinateDocumentStructure.Ref AS DocRef
	|FROM
	|	FilterCriterion.SubordinateDocumentStructure(&DocumentSalesOrder) AS SubordinateDocumentStructure
	|WHERE
	|	(VALUETYPE(SubordinateDocumentStructure.Ref) = Type(Document.CashReceipt)
	|			OR VALUETYPE(SubordinateDocumentStructure.Ref) = Type(Document.PaymentReceipt))";
	
	Query.SetParameter("DocumentSalesOrder", DocumentSalesOrder);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ListOfShipmentDocuments.Add(Selection.DocRef);
	EndDo;
	
	Return ListOfShipmentDocuments;
	
EndFunction

// Procedure updates the list of orders.
//
&AtClient
Procedure UpdateOrdersList()
	
	OrdersArray = OrdersList.UnloadValues();
	List.Parameters.SetParameterValue("OrdersList", OrdersArray);
	
EndProcedure

// Procedure updates the list of payment documents.
//
&AtClient
Procedure UpdateListOfPaymentDocuments()
	
	DocumentSalesOrder = Items.List.CurrentRow;
	If DocumentSalesOrder <> Undefined Then
		ListOfPaymentDocuments = GetListOfLinkedDocuments(DocumentSalesOrder);
		DriveClientServer.SetListFilterItem(PaymentDocuments, "Ref", ListOfPaymentDocuments, True, DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

&AtServer
// Function returns the cash assets type of a document.
//
Function GetCashAssetType(DocumentRef)
	
	StructureCAType = New Structure;
	StructureCAType.Insert("PaymentMethod", DocumentRef.PaymentMethod);
	StructureCAType.Insert("CashAssetType", DocumentRef.CashAssetType);
	StructureCAType.Insert("SetPaymentTerms", DocumentRef.SetPaymentTerms);
	
	Return StructureCAType;
	
EndFunction

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseSalesOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.SalesOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.StateCompletedSalesOrders.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.SalesOrderStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = "In process";
			Else
				FilterItem.RightValue = "Completed";
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By order state " + SelectionOrderStatuses.Description;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Update the list of orders.
	OrdersArray = New Array;
	List.Parameters.SetParameterValue("OrdersList", OrdersArray);
	
	FilterValue = Enums.OperationTypesSalesOrder.OrderForSale;
	
	DriveClientServer.SetListFilterItem(List,"OperationKind",FilterValue);
	
	// Updating the list of payment documents.
	ListOfPaymentDocuments = New ValueList;
	DriveClientServer.SetListFilterItem(PaymentDocuments, "Ref", ListOfPaymentDocuments, True, DataCompositionComparisonType.InList);
	
	// Call from the functions panel.
	If Parameters.Property("Responsible") Then
		FilterResponsible = Parameters.Responsible;
	EndIf;
	
	List.Parameters.SetParameterValue("CurrentDateSession", BegOfDay(CurrentSessionDate()));
	
	CommonClientServer.SetFormItemProperty(Items, "GroupImportantCommandsWorkOrder", "Visible", False);
	
	// Email initialization.
	If Users.IsFullUser()
	OR (IsInRole("OutputToPrinterFileClipboard")
		AND EmailOperations.CheckSystemAccountAvailable())Then
		SystemEmailAccount = EmailOperations.SystemAccount();
	Else
		Items.CIEMailAddress.Hyperlink = False;
		Items.CIContactPersonEmailAddress.Hyperlink = False;
	EndIf;
	
	// Use sales order status.
	If Not Constants.UseSalesOrderStatuses.Get() Then
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	PaintList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisForm);
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisForm);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterState = Settings.Get("FilterState");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	
	// Call is excluded from function panel.
	If Not Parameters.Property("Responsible") Then
		FilterResponsible = Settings.Get("FilterResponsible");
	EndIf;
	Settings.Delete("FilterResponsible");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_SalesInvoice"
	 OR EventName = "NotificationAboutOrderPayment"
	 OR EventName = "NotificationAboutChangingDebt" Then
		UpdateOrdersList();
	EndIf;
	
	If EventName = "NotificationAboutOrderPayment" Then
		UpdateListOfPaymentDocuments();
	EndIf;
	
	If EventName = "Record_SalesOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of button click CreatePayment.
//
&AtClient
Procedure CreatePayment(Command)
	
	CurrentRow = Items.List.CurrentRow;
	If CurrentRow = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersList.Add(CurrentRow);
	
	StructureCAType = GetCashAssetType(CurrentRow);
	CashAssetType = StructureCAType.CashAssetType;
	SetPaymentTerms = StructureCAType.SetPaymentTerms;
	
	BasisParameters = New Structure("Basis, ConsiderBalances", CurrentRow, True);
	If SetPaymentTerms Then
		If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
			OpenForm("Document.CashReceipt.ObjectForm", New Structure("Basis", BasisParameters));
		Else
			OpenForm("Document.PaymentReceipt.ObjectForm", New Structure("Basis", BasisParameters));
		EndIf;
	Else
		ListPaymentDocuments = New ValueList();
		ListPaymentDocuments.Add("CashReceipt", NStr("en = 'Petty cash receipt'; ru = 'Поступление в кассу';pl = 'Kasa przyjmie';es_ES = 'Recibo de la caja menor';es_CO = 'Recibo de la caja menor';tr = 'Küçük kasa makbuzu';it = 'Piccola entrata di cassa';de = 'Portokasse-Quittung'"));
		ListPaymentDocuments.Add("PaymentReceipt", NStr("en = 'Payment receipt'; ru = 'Поступление на счет';pl = 'Płatność wchodząca';es_ES = 'Recibo del pago';es_CO = 'Recibo del pago';tr = 'Ödeme fişi';it = 'Ricevuta di pagamento';de = 'Zahlungsbeleg'"));
		SelectedOrder = Undefined;

		ListPaymentDocuments.ShowChooseItem(New NotifyDescription("CreatePaymentEnd", ThisObject, New Structure("BasisParameters", BasisParameters)),
			NStr("en = 'Select payment method'; ru = 'Выберите способ оплаты';pl = 'Wybierz sposób płatności';es_ES = 'Seleccionar el método de pago';es_CO = 'Seleccionar el método de pago';tr = 'Ödeme yöntemi seç';it = 'Scegli il metodo di pagamento';de = 'Wählen Sie die Zahlungsmethode'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CreatePaymentEnd(Result, AdditionalParameters) Export
    
    BasisParameters = AdditionalParameters.BasisParameters;
    
    
    SelectedOrder = Result;
    If SelectedOrder <> Undefined Then
        If SelectedOrder.Value = "CashReceipt" Then
            OpenForm("Document.CashReceipt.ObjectForm", New Structure("Basis", BasisParameters));
        Else
            OpenForm("Document.PaymentReceipt.ObjectForm", New Structure("Basis", BasisParameters));
        EndIf;
    EndIf;

EndProcedure

// Procedure - handler of clicking the SendEmailToCounterparty button.
//
&AtClient
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(CounterpartyInformationES) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Counterparty);
		StructureRecipient.Insert("Address", CounterpartyInformationES);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmailMessage(SendingParameters);
	
EndProcedure

// Procedure - handler of clicking the SendEmailToContactPerson button.
//
&AtClient
Procedure SendEmailToContactPerson(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ContactPersonESInformation) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.ContactPerson);
		StructureRecipient.Insert("Address", ContactPersonESInformation);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmailMessage(SendingParameters);
	
EndProcedure

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	DriveClient.SalesInvoiceGenerationBasedOnSalesOrder(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSalesOrder(Items.List);
EndProcedure

#Region AttributeEventHandlers

// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

// Procedure - event handler OnChange input field FilterState.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterStateOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	
EndProcedure

// Procedure - event handler OnChange input field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

#EndRegion

// Procedure - handler of the OnActivateRow list events.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
EndProcedure

#EndRegion
