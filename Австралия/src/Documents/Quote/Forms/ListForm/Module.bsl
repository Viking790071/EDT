
#Region FormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Call from the functions panel.
	If Parameters.Property("Responsible") Then
		FilterResponsible = Parameters.Responsible;
	EndIf;
	
	ViewType = CommonSettingsStorage.Load("ViewType", "ViewType_Quotations");
	Items.FormList.Check = NOT ValueIsFilled(ViewType) OR ViewType = "List";
	Items.FormKanban.Check = ValueIsFilled(ViewType) AND ViewType = "Kanban";
	
	UseKanbanForQuotations = Constants.UseKanbanForQuotations.Get();
	Items.GroupTop.ToolTipRepresentation = ?(UseKanbanForQuotations,
		ToolTipRepresentation.Button,
		ToolTipRepresentation.None);
		
	If GetFunctionalOption("UseKanbanForQuotations") Then
		Items.FilterLifecycleStatus.Visible = False;
		Items.ListLifecycleStatus.Visible = False;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.BatchObjectModification
	Items.FormChangeSelected.Visible = AccessRight("Edit", Metadata.Documents.Quote);
	// End StandardSubsystems.BatchObjectModification
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Items.FormKanban.Check Then
		GenerateKanban = True;
		UpdateKanbanBoard();
	EndIf;
	
	FormManagement();
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	FilterLifecycleStatusOnChange(Undefined);
	FilterStatusOnChange(Undefined);
	FilterCounterpartyOnChange(Undefined);
	FilterResponsibleOnChange(Undefined);
	FilterCompanyOnChange(Undefined);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterBasis = Settings.Get("FilterBasis");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	IsKanban = Settings.Get("IsKanban");
	
	// Call is excluded from function panel.
	If Not Parameters.Property("Responsible") Then
		FilterResponsible = Settings.Get("FilterResponsible");
	EndIf;
	Settings.Delete("FilterResponsible");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	DriveClientServer.SetListFilterItem(List, "BasisDocument", FilterBasis, ValueIsFilled(FilterBasis));
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	If IsKanban Then
		UseKanbanForQuotations = Constants.UseKanbanForQuotations.Get();
		Items.FormList.Check = Not UseKanbanForQuotations;
		Items.FormKanban.Check = UseKanbanForQuotations;
		IsKanban = UseKanbanForQuotations;
	EndIf;
	
EndProcedure

// Procedure - notification handler.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutBillPayment"
		OR EventName = "NotificationAboutChangingDebt" Then
		Items.List.Refresh();
	EndIf;
	
	If EventName = "Write_Quotation" Then
		
		If Items.FormKanban.Check Then
			StartUpdateDocumentStatuses();
			UpdateKanbanBoard();
		Else
			Items.List.Refresh();
		EndIf;
		HandleIncreasedRowsList();
		
	EndIf;

	If EventName = "Write_QuotationStatuse" Then
		
		If Items.FormKanban.Check Then
			GenerateKanban = True;
			UpdateKanbanBoard();
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler AtChange enter field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
	If Items.FormKanban.Check Then
		UpdateKanbanBoardAtServer();
	EndIf;
	
EndProcedure

// Procedure - event handler AtChange enter field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
	If Items.FormKanban.Check Then
		UpdateKanbanBoardAtServer();
	EndIf;
	
EndProcedure

// Procedure - event handler AtChange enter field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
	If Items.FormKanban.Check Then
		UpdateKanbanBoardAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterLifecycleStatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "LifecycleStatus", FilterLifecycleStatus, ValueIsFilled(FilterLifecycleStatus));
	
	If Items.FormKanban.Check Then
		UpdateKanbanBoardAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
	
	If Items.FormKanban.Check Then
		UpdateKanbanBoardAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

// Procedure - event handler OnActivateRow of dynamic list List.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure - handler of clicking the SendEmailToCounterparty button.
//
&AtClient
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Undefined;
	If IsKanban Then
		ListCurrentData = Items[CurrentTable].CurrentData;
	Else
		ListCurrentData = Items.List.CurrentData;
	EndIf;
	
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
	
	ListCurrentData = Undefined;
	If IsKanban Then
		ListCurrentData = Items[CurrentTable].CurrentData;
	Else
		ListCurrentData = Items.List.CurrentData;
	EndIf;
	
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
Procedure Kanban(Command)
	
	StartUpdateDocumentStatuses();
	
	Items.FormKanban.Check = True;
	Items.FormList.Check = False;
	
	GenerateKanban = True;
	UpdateKanbanBoard();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure List(Command)
	
	Items.FormKanban.Check = False;
	Items.FormList.Check = True;
	FormManagement();
	
EndProcedure

&AtClient
Procedure ConvertToSalesOrder()
	
	If (TypeOf(CurrentItem) = Type("FormTable")
		AND CurrentItem.CurrentData <> Undefined
		AND TypeOf(CurrentItem.SelectedRows) = Type("Array")) Then
		
		Quotations = New Array;
		
		For Each SelectedQuote In CurrentItem.SelectedRows Do
			
			Quotations.Add(CurrentItem.Rowdata(SelectedQuote).Quotation);
			
		EndDo;
		
		ConvertToSalesOrderAtClient(Quotations);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ConvertToWorkOrder(Command)
	
	If TypeOf(CurrentItem) = Type("FormTable")
		And CurrentItem.CurrentData <> Undefined
		And TypeOf(CurrentItem.SelectedRows) = Type("Array") Then
		
		Quotations = New Array;
		
		For Each SelectedQuote In CurrentItem.SelectedRows Do
			
			Quotations.Add(CurrentItem.Rowdata(SelectedQuote).Quotation);
			
		EndDo;
		
		ConvertToWorkOrderAtClient(Quotations);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseQuotation()
	
	If (TypeOf(CurrentItem) = Type("FormTable")
		AND CurrentItem.CurrentData <> Undefined
		AND TypeOf(CurrentItem.SelectedRows) = Type("Array")) Then
		
		Quotations = New Array;
		
		For Each SelectedQuote In CurrentItem.SelectedRows Do
			
			Quotations.Add(CurrentItem.Rowdata(SelectedQuote).Quotation);
			
		EndDo;
		
		If Quotations.Count() > 1 Then
			Str = NStr("en = 'Quotations closed'; ru = 'Коммерческие предложения закрыты';pl = 'Oferty cenowe zamknięte';es_ES = 'Cerrar los presupuestos';es_CO = 'Cerrar los presupuestos';tr = 'Teklifler kapatıldı';it = 'Preventivi chiusi';de = 'Angebote geschlossen'");
		Else
			Str = NStr("en = 'Quotation closed'; ru = 'Коммерческое предложение закрыто';pl = 'Oferty cenowe zamknięte';es_ES = 'Cerrar el presupuesto';es_CO = 'Cerrar el presupuesto';tr = 'Teklif kapatıldı';it = 'Preventivo chiuso';de = 'Angebot geschlossen'");
		EndIf;
		
		CloseQuotationsAtServer(Quotations);
		
		Notify("Write_Quotation", Quotations, ThisObject);
		
		ShowUserNotification(
			Str,
			,
			,
			PictureLib.Information32);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ConvertToSalesInvoice()
	
	If (TypeOf(CurrentItem) = Type("FormTable")
		AND CurrentItem.CurrentData <> Undefined
		AND TypeOf(CurrentItem.SelectedRows) = Type("Array")) Then
		
		Quotations = New Array;
		
		For Each SelectedQuote In CurrentItem.SelectedRows Do
			
			Quotations.Add(CurrentItem.Rowdata(SelectedQuote).Quotation);
			
		EndDo;
		
		ConvertToSalesInvoiceAtClient(Quotations);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateKanban(Command)
	
	OpenForm("Document.Quote.ObjectForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateKanban(Command)
	
	UpdateKanbanBoard();
	
EndProcedure

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

#EndRegion

#Region KanbanFormItemsEventHandlers

&AtClient
Procedure Attachable_KanbanSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Item.CurrentData.Quotation);
	
EndProcedure

&AtClient
Procedure Attachable_KanbanOnActivateCell(Item)
	
	If Item.CurrentData <> Undefined Then
		If CurrentQuotation <> Item.CurrentData.Quotation Then
			CurrentTable = Item.Name;
			CurrentQuotation = Item.CurrentData.Quotation;
			ClearActivation(Item.Name);
		EndIf;
	EndIf;
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
EndProcedure

&AtClient
Procedure Attachable_KanbanBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	OpenForm("Document.Quote.ObjectForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_KanbanDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If DragParameters.Value.Count() > 0
		AND TypeOf(DragParameters.Value[0]) <> Type("Number") Then
		
		NewStatus = Item.RowFilter.Status;
		
		QuotesArrayValue = DragParameters.Value;
		QuotesArray = New Array();
		For Each ChangedQuote In QuotesArrayValue Do
			If ChangedQuote.Status <> NewStatus Then
				ChangeQuoteStateAtServer(ChangedQuote.Quotation, NewStatus);
				QuotesArray.Add(ChangedQuote.Quotation);
			EndIf;
		EndDo;
		
		Notify("Write_Quotation", QuotesArray, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkFoDeletionBinDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure MarkFoDeletionBinDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	If DragParameters.Value.Count() > 1 Then
		Str = NStr("en = 'Quotations marked for deletion'; ru = 'Коммерческие предложения помечены на удаление';pl = 'Oferty cenowe zaznaczone do usunięcia';es_ES = 'Presupuestos marcados para borrar';es_CO = 'Presupuestos marcados para borrar';tr = 'Teklifler silinmek üzere işaretlendi';it = 'Preventivi contrassegnati per l''eliminazione';de = 'Zum Löschen vorgemerkte Angebote'");
	Else
		Str = NStr("en = 'Quotation marked for deletion'; ru = 'Коммерческое предложение помечено на удаление';pl = 'Oferty cenowe zaznaczone do usunięcia';es_ES = 'Presupuesto marcado para borrar';es_CO = 'Presupuesto marcado para borrar';tr = 'Teklif silinmek üzere işaretlendi';it = 'Preventivo contrassegnato per l''eliminazione';de = 'Zum Löschen vorgemerktes Angebot'");
	EndIf;
	
	QuotationsArray = New Array;
	
	For Each QuotationLine In DragParameters.Value Do
		QuotationsArray.Add(QuotationLine.Quotation);
	EndDo;
	
	MarkForDeletionBinDragAtServer(QuotationsArray);
	
	UpdateKanbanBoard();
	
	ShowUserNotification(
		NStr("en = 'Deletion mark'; ru = 'Пометка удаления';pl = 'Zaznaczenie usunięcia';es_ES = 'Marca de borrado';es_CO = 'Marca de borrado';tr = 'Silme işareti';it = 'Contrassegno per l''eliminazione';de = 'Löschmarkierung'"),
		,
		Str,
		PictureLib.Information32);
		
EndProcedure

&AtClient
Procedure DecorationCloseQuotationDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationCloseQuotationDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	If DragParameters.Value.Count() > 1 Then
		Str = NStr("en = 'Quotations closed'; ru = 'Коммерческие предложения закрыты';pl = 'Oferty cenowe zamknięte';es_ES = 'Cerrar los presupuestos';es_CO = 'Cerrar los presupuestos';tr = 'Teklifler kapatıldı';it = 'Preventivi chiusi';de = 'Angebote geschlossen'");
	Else
		Str = NStr("en = 'Quotation closed'; ru = 'Коммерческое предложение закрыто';pl = 'Oferty cenowe zamknięte';es_ES = 'Cerrar el presupuesto';es_CO = 'Cerrar el presupuesto';tr = 'Teklif kapatıldı';it = 'Preventivo chiuso';de = 'Angebot geschlossen'");
	EndIf;
	
	QuotationsArray = New Array;
	
	For Each QuotationLine In DragParameters.Value Do
		QuotationsArray.Add(QuotationLine.Quotation);
	EndDo;
	
	CloseQuotationsAtServer(QuotationsArray);
	
	Notify("Write_Quotation", QuotationsArray, ThisObject);
	
	ShowUserNotification(
		Str,
		,
		,
		PictureLib.Information32);

EndProcedure

&AtClient
Procedure DecorationToSalesOrderDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationToSalesOrderDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	QuotationsArray = New Array;
	
	For Each QuotationLine In DragParameters.Value Do
		QuotationsArray.Add(QuotationLine.Quotation);
	EndDo;
	
	ConvertToSalesOrderAtClient(QuotationsArray);
	
EndProcedure

&AtClient
Procedure DecorationToWorkOrderDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationToWorkOrderDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		Or DragParameters.Value.Count() = 0 Then
		Return;
	EndIf;
	
	QuotationsArray = New Array;
	
	For Each QuotationLine In DragParameters.Value Do
		QuotationsArray.Add(QuotationLine.Quotation);
	EndDo;
	
	ConvertToWorkOrderAtClient(QuotationsArray);
	
EndProcedure

&AtClient
Procedure DecorationToSalesInvoiceDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationToSalesInvoiceDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	QuotationsArray = New Array;
	
	For Each QuotationLine In DragParameters.Value Do
		QuotationsArray.Add(QuotationLine.Quotation);
	EndDo;
	
	ConvertToSalesInvoiceAtClient(QuotationsArray);
	
EndProcedure

#EndRegion

#Region Private

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Counterparty");
	DriveClient.InfoPanelProcessListRowActivation(ThisForm,
		InfPanelParameters,
		?(Items.FormKanban.Check, CurrentTable, ""));
	
EndProcedure

#Region Kanban

&AtClient
Procedure StartUpdateDocumentStatuses()
	
	TimeConsumingOperation = StartExecuteAtServer();
	Items.GroupBackgroundJob.Visible = (TimeConsumingOperation.Status = "Running");
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	CompletionNotification = New NotifyDescription("ExecuteActionCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

&AtClient
Procedure ExecuteActionCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Items.GroupBackgroundJob.Visible = False;
	UpdateKanbanBoard();
	
 EndProcedure

&AtServer
Function StartExecuteAtServer()
	
	ProcedureParameters = New Structure;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	
	Return TimeConsumingOperations.ExecuteInBackground("DriveServer.UpdateDocumentStatuses",
		ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtServer
Procedure FormManagement()
	
	CanBeEdited = AccessRight("Edit", Metadata.Documents.Quote);
	IsKanban = Items.FormKanban.Check;
	
	If CanBeEdited Then
		
		Items.FormCreate.Visible = Not IsKanban;
		Items.FormCopy.Visible = Not IsKanban;
		Items.ImportantCommandsGroup.Visible = Not IsKanban;
		Items.GroupGlobalCommands.Visible = Not IsKanban;
		
		Items.GroupKanbanCommands.Visible = IsKanban;
		
	EndIf;
	
	Items.List.Visible = Not IsKanban;
	Items.GroupKanban.Visible = IsKanban;
	Items.QuotationClosure.Visible = IsKanban;
	
	Items.KanbanListCounterparty.Visible = IsKanban;
	Items.DetailsListCounterparty.Visible = Not IsKanban;
	Items.KanbanListDetailsContactPerson.Visible = IsKanban;
	Items.ListDetailsContactPerson.Visible = Not IsKanban;
	Items.KanbanCounterpartiesOpenContactInformationForm.Visible = IsKanban;
	Items.CatalogCounterpartiesOpenContactInformationForm.Visible = Not IsKanban;
	Items.KanbanOpenSupplierQuoteDocuments.Visible = IsKanban;
	Items.OpenSupplierQuoteDocuments.Visible = Not IsKanban;
	Items.KanbanOpenEventsByBill.Visible = IsKanban;
	Items.OpenEventsByBill.Visible = Not IsKanban;
	
	Items.ListSearchString.Visible = Not IsKanban;
	Items.ListSearchControl.Visible = Not IsKanban;
	
EndProcedure

#Region KanbanUpdating

&AtClient
Procedure UpdateKanbanBoard()
	
	UpdateKanbanBoardAtServer();
	
	If GenerateKanban Then
		GenerateKanbanColums();
		SetKanbanContextMenu();
		SetKanbanFilter();
		GenerateKanban = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateKanbanBoardAtServer()
	
	// Refill table
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	QuotationKanbanStatusesSliceLast.Status AS Status,
	|	Quote.Ref AS Quotation,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Comment AS Comment,
	|	Quote.DocumentAmount AS Amount,
	|	Quote.DocumentCurrency AS Currency,
	|	Quote.ValidUntil AS IssuedOn,
	|	Counterparties.ContactPerson AS ContactPerson,
	|	CASE
	|		WHEN Quote.Posted
	|			THEN ISNULL(QuotationStatuses.Status, VALUE(Enum.QuotationStatuses.Sent))
	|		ELSE VALUE(Enum.QuotationStatuses.Draft)
	|	END AS LifecycleStatus
	|FROM
	|	Document.Quote AS Quote
	|		LEFT JOIN InformationRegister.QuotationKanbanStatuses.SliceLast AS QuotationKanbanStatusesSliceLast
	|		ON Quote.Ref = QuotationKanbanStatusesSliceLast.Quotation
	|		LEFT JOIN InformationRegister.QuotationStatuses AS QuotationStatuses
	|		ON Quote.Ref = QuotationStatuses.Document
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Quote.Counterparty = Counterparties.Ref
	|WHERE
	|	Quote.Posted
	|	AND &FilterStringKanban
	|	AND ISNULL(QuotationKanbanStatusesSliceLast.Status, VALUE(Catalog.QuotationStatuses.EmptyRef)) <> VALUE(Catalog.QuotationStatuses.Converted)";
	
	FilterStructure = FilterStructureKanban();
	Query.Text = StrReplace(Query.Text, "AND &FilterStringKanban", FilterStructure.FilterStringKanban);
	
	For Each FilterKanban In FilterStructure.ParametersKanban Do
		Query.SetParameter(FilterKanban.Key, FilterKanban.Value);
	EndDo;
	
	KanbanTable.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Function FilterStructureKanban()
	
	FilterStructure = New Structure("FilterStringKanban, ParametersKanban");
	
	StringsArray = New Array;
	ParametersKanban = New Map;
	
	If ValueIsFilled(FilterLifecycleStatus) Then
		StringsArray.Add(" AND QuotationStatuses.Status = (&FilterLifecycleStatus) ");
		ParametersKanban.Insert("FilterLifecycleStatus", FilterLifecycleStatus);
	EndIf;
	
	If ValueIsFilled(FilterCounterparty) Then
		StringsArray.Add(" AND Quote.Counterparty = (&FilterCounterparty) ");
		ParametersKanban.Insert("FilterCounterparty", FilterCounterparty);
	EndIf;
	
	If ValueIsFilled(FilterResponsible) Then
		StringsArray.Add(" AND Quote.Responsible = (&FilterResponsible) ");
		ParametersKanban.Insert("FilterResponsible", FilterResponsible);
	EndIf;
	
	If ValueIsFilled(FilterCompany) Then
		StringsArray.Add(" AND Quote.Company = (&FilterCompany) ");
		ParametersKanban.Insert("FilterCompany", FilterCompany);
	EndIf;
	
	If ValueIsFilled(FilterStatus) Then
		StringsArray.Add(" AND QuotationKanbanStatusesSliceLast.Status = (&FilterStatus) ");
		ParametersKanban.Insert("FilterStatus", FilterStatus);
	EndIf;
	
	FilterStructure.FilterStringKanban = ?(StringsArray.Count() = 0, "AND TRUE", StrConcat(StringsArray, Chars.LF));
	FilterStructure.ParametersKanban = ParametersKanban;
	
	Return FilterStructure;
	
EndFunction

#EndRegion

#Region KanbanFormItemsCreation

// Query for KanbanColums table
//
&AtServer
Procedure FillKanbanColumsTable()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuotationStatuses.Ref AS Status,
		|	QuotationStatuses.HighlightColor AS Color,
		|	QuotationStatuses.Order AS Order,
		|	QuotationStatuses.Code AS StatusCode,
		|	QuotationStatuses.Description AS StatusDescription,
		|	""Table_"" + QuotationStatuses.Code AS ItemTableName,
		|	&KanbanPrefix + ""Group_"" + QuotationStatuses.Code AS ItemColumnName
		|FROM
		|	Catalog.QuotationStatuses AS QuotationStatuses
		|WHERE
		|	NOT QuotationStatuses.DeletionMark
		|	AND NOT QuotationStatuses.Disabled
		|
		|ORDER BY
		|	Order";
	
	Query.SetParameter("KanbanPrefix", KanbanPrefix());
	
	QueryResult = Query.Execute();
	
	KanbanColumns.Clear();
	
	Items.DecorationNoColumns.Visible = QueryResult.IsEmpty();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewKanbanColumn = KanbanColumns.Add();
		FillPropertyValues(NewKanbanColumn, SelectionDetailRecords);
		NewKanbanColumn.Color				= SelectionDetailRecords.Color.Get();
		NewKanbanColumn.ItemTableName		= StrReplace(NewKanbanColumn.ItemTableName, " ", "");
		NewKanbanColumn.ItemColumnName		= StrReplace(NewKanbanColumn.ItemColumnName, " ", "");
		NewKanbanColumn.StatusCode			= StrReplace(NewKanbanColumn.StatusCode, " ", "");
		
	EndDo;
	
EndProcedure

// Kanban form items creation
// 
&AtServer
Procedure GenerateKanbanColums()
	
	DeleteKanbanItems();
	
	FillKanbanColumsTable();
	
	KanbanPrefix = KanbanPrefix();
	
	For Each KanbanColumn In KanbanColumns Do
		
		// Group for kanban
		ItemGroup						= Items.Insert(KanbanColumn.ItemColumnName, Type("FormGroup"), Items.GroupKanban);
		ItemGroup.Type					= FormGroupType.UsualGroup;
		ItemGroup.Title					= KanbanColumn.StatusDescription;
		ItemGroup.ToolTip				= KanbanColumn.StatusDescription;
		ItemGroup.Representation		= UsualGroupRepresentation.WeakSeparation;
		
		// Kanban table
		ItemTable						= Items.Insert(KanbanColumn.ItemTableName, Type("FormTable"), ItemGroup);
		ItemTable.DataPath				= "KanbanTable";
		ItemTable.AutoInsertNewRow		= True;
		ItemTable.HorizontalScrollBar	= ScrollBarUse.DontUse;
		ItemTable.TitleLocation			= FormItemTitleLocation.None;
		ItemTable.SelectionMode			= TableSelectionMode.MultiRow;
		ItemTable.RowSelectionMode		= TableRowSelectionMode.Row;
		ItemTable.Header				= False;
		ItemTable.CommandBar.Visible	= False;
		
		ItemTable.SetAction("Selection",		"Attachable_KanbanSelection");
		ItemTable.SetAction("OnActivateCell",	"Attachable_KanbanOnActivateCell");
		ItemTable.SetAction("BeforeAddRow",		"Attachable_KanbanBeforeAddRow");
		ItemTable.SetAction("Drag",				"Attachable_KanbanDrag");
		
		// Kanban Item
		
		// Main group
		MainGroupKanbanName				= "TableMainGroup_" + KanbanColumn.StatusCode;
		MainGroupKanban					= Items.Insert(MainGroupKanbanName, Type("FormGroup"), ItemTable);
		MainGroupKanban.Type			= FormGroupType.ColumnGroup;
		
		// Bottom group
		MainBottomGroupKanbanName		= "TableMainBottomGroup_" + KanbanColumn.StatusCode;
		MainBottomGroupKanban			= Items.Insert(MainBottomGroupKanbanName, Type("FormGroup"), MainGroupKanban);
		MainBottomGroupKanban.Type		= FormGroupType.ColumnGroup;
		MainBottomGroupKanban.Group		= ColumnsGroup.Vertical;
		
		// Line Counterparty, Amount, Currency
		BottomGroupKanbanName			= "TableBottomGroup_" + KanbanColumn.StatusCode;
		BottomGroupKanban				= Items.Insert(BottomGroupKanbanName, Type("FormGroup"), MainBottomGroupKanban);
		BottomGroupKanban.Type			= FormGroupType.ColumnGroup;
		BottomGroupKanban.Group			= ColumnsGroup.Horizontal;
		
		// Counterparty
		BottomItemKanbanName			= "TableBottomItem_" + KanbanColumn.StatusCode;
		BottomItemKanban				= Items.Insert(BottomItemKanbanName, Type("FormField"), BottomGroupKanban);
		BottomItemKanban.Type			= FormFieldType.InputField;
		BottomItemKanban.DataPath		= "KanbanTable.Counterparty";
		
		// Amount Currency
		BottomUpGroupKanbanName			= "TableBottomUpGroup_" + KanbanColumn.StatusCode;
		BottomUpGroupKanban				= Items.Insert(BottomUpGroupKanbanName, Type("FormGroup"), BottomGroupKanban);
		BottomUpGroupKanban.Type		= FormGroupType.ColumnGroup;
		BottomUpGroupKanban.Group		= ColumnsGroup.InCell;
		
		BottomItemKanbanName			= "TableBottomUpItem1_" + KanbanColumn.StatusCode;
		BottomItemKanban				= Items.Insert(BottomItemKanbanName, Type("FormField"), BottomUpGroupKanban);
		BottomItemKanban.Type			= FormFieldType.InputField;
		BottomItemKanban.HorizontalAlign = ItemHorizontalLocation.Left;
		BottomItemKanban.DataPath		= "KanbanTable.Amount";

		BottomItemKanbanName			= "TableBottomUpItem2_" + KanbanColumn.StatusCode;
		BottomItemKanban				= Items.Insert(BottomItemKanbanName, Type("FormField"), BottomUpGroupKanban);
		BottomItemKanban.Type			= FormFieldType.InputField;
		BottomItemKanban.HorizontalAlign = ItemHorizontalLocation.Left;
		BottomItemKanban.DataPath		= "KanbanTable.Currency";
		
		// Line Comment
		BottomDownGroupKanbanName		= "TableBottomDownGroup_" + KanbanColumn.StatusCode;
		BottomDownGroupKanban			= Items.Insert(BottomDownGroupKanbanName, Type("FormGroup"), MainBottomGroupKanban);
		BottomDownGroupKanban.Type		= FormGroupType.ColumnGroup;
		
		BottomDownItemKanbanName		= "TableBottomDownItem_" + KanbanColumn.StatusCode;
		BottomDownItemKanban			= Items.Insert(BottomDownItemKanbanName, Type("FormField"), BottomDownGroupKanban);
		BottomDownItemKanban.Type		= FormFieldType.InputField;
		BottomDownItemKanban.DataPath	= "KanbanTable.Comment";
		
		// Top group
		TopGroupKanbanName				= "TableTopGroup_" + KanbanColumn.StatusCode;
		TopGroupKanban					= Items.Insert(TopGroupKanbanName, Type("FormGroup"), MainGroupKanban, MainBottomGroupKanban);
		TopGroupKanban.Type				= FormGroupType.ColumnGroup;
		TopGroupKanban.Group			= ColumnsGroup.InCell;
		
		TopItemKanbanName				= "TableTopItem_" + KanbanColumn.StatusCode;
		TopItemKanban					= Items.Insert(TopItemKanbanName, Type("FormField"), TopGroupKanban);
		TopItemKanban.Type				= FormFieldType.InputField;
		TopItemKanban.DataPath			= "KanbanTable.Quotation";
		TopItemKanban.DropListButton	= False;
		TopItemKanban.OpenButton		= False;
		TopItemKanban.BackColor			= KanbanColumn.Color;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetKanbanContextMenu()
	
	For Each KanbanColumn In KanbanColumns Do
		
		// Visible for predefined items
		ItemTable = Items[KanbanColumn.ItemTableName];
		For Each ChildItem In ItemTable.ContextMenu.ChildItems Do
			ChildItem.Visible = False;
		EndDo;
		
		// New context menu commands
		ChangeStateGroup					= "ChangeStateGroup_" + KanbanColumn.StatusCode;
		StateGroup							= Items.Add(ChangeStateGroup, Type("FormGroup"), ItemTable.ContextMenu);
		StateGroup.Type						= FormGroupType.ButtonGroup;
		
		ConvertIntoRejectName				= "Close_" + KanbanColumn.StatusCode;
		CommandIntoReject					= Items.Add(ConvertIntoRejectName, Type("FormButton"), ItemTable.ContextMenu);
		CommandIntoReject.Title				= NStr("en = 'Close'; ru = 'Закрыть';pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
		CommandIntoReject.CommandName		= "CloseQuotation";
		
		ConvertIntoCustomerName				= "CommandConvertToSalesOrder_" + KanbanColumn.StatusCode;
		CommandIntoCustomer					= Items.Add(ConvertIntoCustomerName, Type("FormButton"), ItemTable.ContextMenu);
		CommandIntoCustomer.Title			= NStr("en = 'Convert to sales order'; ru = 'Перевести в заказ покупателя';pl = 'Konwertuj na zamówienie sprzedaży';es_ES = 'Convertir a una Orden de Venta';es_CO = 'Convertir a una Orden de Venta';tr = 'Satış siparişine dönüştür';it = 'Converti in ordine cliente';de = 'In Kundenauftrag umsetzen'");
		CommandIntoCustomer.CommandName		= "ConvertToSalesOrder";
		
		ConvertIntoCustomerName				= "CommandConvertToWorkOrder_" + KanbanColumn.StatusCode;
		CommandIntoCustomer					= Items.Add(ConvertIntoCustomerName, Type("FormButton"), ItemTable.ContextMenu);
		CommandIntoCustomer.Title			= NStr("en = 'Convert to work order'; ru = 'Перевести в заказ-наряд';pl = 'Konwertuj na zlecenie pracy';es_ES = 'Convertir en orden de trabajo';es_CO = 'Convertir en orden de trabajo';tr = 'İş emrine dönüştür';it = 'Conversione alla commessa';de = 'In Arbeitsauftrag konvertieren'");
		CommandIntoCustomer.CommandName		= "ConvertToWorkOrder";
		
		ConvertIntoCustomerName				= "CommandConvertToSalesInvoice_" + KanbanColumn.StatusCode;
		CommandIntoCustomer					= Items.Add(ConvertIntoCustomerName, Type("FormButton"), ItemTable.ContextMenu);
		CommandIntoCustomer.Title			= NStr("en = 'Convert to sales invoice'; ru = 'Перевести в инвойс покупателю';pl = 'Konwertuj na fakturę sprzedaży';es_ES = 'Convertir a una Factura de Venta';es_CO = 'Convertir a una Factura de Venta';tr = 'Satış faturasına dönüştür';it = 'Converti in Fattura di vendita';de = 'In Verkaufsrechnung umsetzen'");
		CommandIntoCustomer.CommandName		= "ConvertToSalesInvoice";
		
	EndDo;
	
EndProcedure

// Old form items deletion
//
&AtServer
Procedure DeleteKanbanItems()
	
	For Each KanbanColumn In KanbanColumns Do
		Items.Delete(Items[KanbanColumn.ItemColumnName]);
	EndDo;
	
EndProcedure

// Status filter for leads in column
//
&AtClient
Procedure SetKanbanFilter()
	
	For Each Column In KanbanColumns Do
		
		Items[Column.ItemTableName].RowFilter = New FixedStructure("Status", Column.Status);
		
	EndDo;
	
EndProcedure

&AtServer
Function KanbanPrefix()
	
	Return "_Kanban_";
	
EndFunction

// Clear rows activation for other columns
//
&AtClient
Function ClearActivation(ExceptionTable = "")
	
	For Each Column In KanbanColumns Do
		If StrCompare(Column.ItemTableName, ExceptionTable) <> 0 Then
			Items[Column.ItemTableName].SelectedRows.Clear();
		EndIf;
	EndDo;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure ChangeQuoteStateAtServer(Quotation, Status)
	
	QuotationStatuses.SetQuotationStatus(Quotation, Status);
	
EndProcedure

&AtServerNoContext
Procedure MarkForDeletionBinDragAtServer(Quotations)
	
	For Each Quotation In Quotations Do
		
		If NOT ValueIsFilled(Quotation) Then
			Continue;
		EndIf;
		
		ObjectQuotation = Quotation.Ref.GetObject();
		ObjectQuotation.SetDeletionMark(True);
		ObjectQuotation.Write();
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ConvertToSalesOrderAtClient(Quotations)
	
	For Each Quotation In Quotations Do
		
		If NOT ValueIsFilled(Quotation) Then
			Continue;
		EndIf;
		
		BasisParameters = New Structure("Basis", Quotation);
		OpenForm("Document.SalesOrder.ObjectForm", BasisParameters, , True);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ConvertToWorkOrderAtClient(Quotations)
	
	For Each Quotation In Quotations Do
		
		If Not ValueIsFilled(Quotation) Then
			Continue;
		EndIf;
		
		BasisParameters = New Structure("Basis", Quotation);
		OpenForm("Document.WorkOrder.ObjectForm", BasisParameters, , True);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ConvertToSalesInvoiceAtClient(Quotations)
	
	For Each Quotation In Quotations Do
		
		If NOT ValueIsFilled(Quotation) Then
			Continue;
		EndIf;
		
		BasisParameters = New Structure("Basis", Quotation);
		OpenForm("Document.SalesInvoice.ObjectForm", BasisParameters, , True);
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure CloseQuotationsAtServer(Quotations)
	
	For Each Quotation In Quotations Do
		
		If NOT ValueIsFilled(Quotation) Then
			Continue;
		EndIf;
		
		ChangeQuoteStateAtServer(Quotation, Catalogs.QuotationStatuses.Closed);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion
