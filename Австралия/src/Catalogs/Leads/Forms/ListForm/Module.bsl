#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Leads, DataLoadSettings, ThisObject);
	Items.DataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	// Establish the form settings for the case of the opening in choice mode
	Items.List.ChoiceMode		= Parameters.ChoiceMode;
	Items.List.MultipleChoice	= ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.GroupViewType.Visible = False;
	Else
		PurposeUseKey = "List";
	EndIf;
	
	If NOT Items.List.ChoiceMode Then
		FormFilterOption = FilterOptionForSetting();
		WorkWithFilters.RestoreFilterSettings(ThisObject, List,,,New Structure("FilterPeriod", "Created"), FormFilterOption, True);
	Else
		PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(New StandardPeriod);
	EndIf;
	
	SetFilterByResult();
	
	ViewType = CommonSettingsStorage.Load("ViewType", "ViewType_LeadsList");
	FilterCampaign = CommonSettingsStorage.Load("Filter", "FilterCampaign");
	DriveClientServer.SetListFilterItem(List, "Campaign", FilterCampaign, ValueIsFilled(FilterCampaign));

	If Not ValueIsFilled(FilterCampaign) Then
		ViewType = "List";
	EndIf;
	
	SetActivityChoiseList(FilterCampaign);
	
	Items.FormList.Check = NOT ValueIsFilled(ViewType) OR ViewType = "List" OR Parameters.ChoiceMode;
	Items.FormKanban.Check = ValueIsFilled(ViewType) AND ViewType = "Kanban" AND NOT Parameters.ChoiceMode;
	
	FormManagement();
	
	SetConditionalAppearanceInCampaignsColorsAtServer();
	
	ContactInformationPanel.OnCreateAtServer(ThisObject, "ContactInformation");
	
	UseDocumentEvent = GetFunctionalOption("UseDocumentEvent");
	
	// StandardSubsystems.BatchObjectModification
	Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.Leads);
	// End StandardSubsystems.BatchObjectModification
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Items.FormKanban.Check Then
		
		GenerateKanban = True;
		UpdateKanbanBoard();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_Lead" Then
		
		If Items.FormKanban.Check Then
			UpdateKanbanBoard();
		EndIf;
		Items.List.Refresh();
		RefreshContactInformationPanelServer();
		
	EndIf;
	
	If EventName = "PeriodClick_Leads" Then
		
		If Items.FormKanban.Check Then
			UpdateKanbanBoard();
		Else
			SetFilterByResult();
		EndIf;
		
	EndIf;
	
	If EventName = "Write_Campaigns" Then
		
		If Items.FormKanban.Check Then
			GenerateKanban = True;
			UpdateKanbanBoard();
		EndIf;
		SetConditionalAppearanceAndUpdateActivityCommands();
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SaveFilterSettings();

EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Campaigns") Then
		
		LeadsArray = New Array;
		For Each ChangedLead In ChangedLeads Do
			ChangeLeadStateAtServer(ChangedLead.Lead, SelectedValue, , PredefinedValue("Catalog.CampaignActivities.EmptyRef"));
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	ElsIf TypeOf(SelectedValue) = Type("CatalogRef.Employees") Then
		
		LeadsArray = New Array;
		For Each ChangedLead In ChangedLeads Do
			ChangeLeadStateAtServer(ChangedLead.Lead, , SelectedValue);
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, "List", "Created", , "PeriodClick_Leads");
	
EndProcedure

&AtClient
Procedure FilterTagChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Tags.Tag", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterSalesRepChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("SalesRep", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterCampaignOnChange(Item)
	
	SetActivityChoiseList(FilterCampaign);
	
	DriveClientServer.DeleteListFilterItem(List, "Activity");
	
	DriveClientServer.SetListFilterItem(List, "Campaign", FilterCampaign, ValueIsFilled(FilterCampaign));
	
	If Items.FormKanban.Check Then
		GenerateKanban = True;
		UpdateKanbanBoard();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterActivityChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Activity", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
	If Items.FormKanban.Check Then
		GenerateKanban = True;
		UpdateKanbanBoard();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterAcquisitionChannelChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("AcquisitionChannel", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterResultChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ValuePresentation = String(SelectedValue);
	If NOT ValueIsFilled(SelectedValue) Then
		ValuePresentation = "Active";
	EndIf;
	
	SetLabelAndListFilter("ClosureResult", Item.Parent.Name, SelectedValue, ValuePresentation);
	SetFilterByResult();
	
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = NOT Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

&AtClient
Procedure FilterSearchClearing(Item, StandardProcessing)
	
	FilterSearch = "";
	If Items.FormKanban.Check Then
		UpdateKanbanBoard();
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationIntoCustomerDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationRejectedLeadDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationIntoCustomerDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	For Each DragValue In DragParameters.Value Do
		
		Lead = DragValue.Lead;
		
		If ValueIsFilled(Lead) AND CanBeTransferredToClient(Lead) Then
			
			Counterparty = ConvertIntoCustomerAtServer(Lead);
			
			MessageText = NStr("en = 'Lead %1 is converted into customer %2'; ru = 'Лид %1 переведен в клиента %2';pl = 'Lead %1 został przekształcony w nabywcę %2';es_ES = 'El lead %1 se ha convertido al cliente %2';es_CO = 'El lead %1 se ha convertido al cliente %2';tr = '%1 müşteri adayı %2 müşterisine dönüştürüldü';it = 'Il potenziale cliente %1 è stato convertito nel cliente %2';de = 'Lead %1 wird in Kunde %2 umgewandelt'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Lead, Counterparty);
			CommonClientServer.MessageToUser(MessageText, Counterparty);
			
		EndIf;
		
	EndDo;
	
	Notify("Write_Lead");
	
EndProcedure

&AtClient
Procedure DecorationRejectedLeadDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	
	For Each DragValue In DragParameters.Value Do
		
		If NOT ValueIsFilled(DragValue.Lead) Then
			Continue;
		EndIf;
		
		NewRejectedLead = ChangedLeads.Add();
		NewRejectedLead.Lead = DragValue.Lead;
		
	EndDo;
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	Res = New NotifyDescription("DoAfterCloseRejectedLead", ThisObject);
	OpenForm("Catalog.Leads.Form.FormOfRejectedLead",,,,,,Res, FormWindowOpeningMode.LockOwnerWindow);
	
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
		Str = NStr("en = 'Leads marked for deletion'; ru = 'Помеченные на удаление лиды';pl = 'Leady zaznaczone do usunięcia';es_ES = 'Leads marcados para borrar';es_CO = 'Leads marcados para borrar';tr = 'Silinmek üzere işaretlenmiş müşteri adayları Silinmek üzere işaretlenmiş müşteri adayları';it = 'Potenziali clienti contrassegnati per l''eliminazione';de = 'Zum Löschen vorgemerkte Leads'");
	Else
		Str = NStr("en = 'Lead marked for deletion'; ru = 'Лид помечен на удаление';pl = 'Lead zaznaczony do usunięcia';es_ES = 'Lead marcado para borrar';es_CO = 'Lead marcado para borrar';tr = 'Silinmek üzere işaretlenen müşteri adayı';it = 'Potenziale Cliente contrassegnato per l''eliminazione';de = 'Zum Löschen vorgemerkter Lead'");
	EndIf;
	
	LeadsArray = New Array;
	
	For Each Lead In DragParameters.Value Do
		LeadsArray.Add(Lead.Lead);
	EndDo;
	
	MarkFoDeletionBinDragAtServer(LeadsArray);
	
	UpdateKanbanBoard();
	
	ShowUserNotification(
		NStr("en = 'Deletion mark'; ru = 'Пометка удаления';pl = 'Zaznaczenie usunięcia';es_ES = 'Marca de borrado';es_CO = 'Marca de borrado';tr = 'Silme işareti';it = 'Contrassegno per l''eliminazione';de = 'Löschmarkierung'"),
		,
		Str,
		PictureLib.Information32);
		
EndProcedure

&AtClient
Procedure FilterSearchEditTextChange(Item, Text, StandardProcessing)
	
	FilterSearch = Text;
	If Items.FormKanban.Check Then
		UpdateKanbanBoard();
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Item.CurrentRow) <> Type("DynamicListGroupRow") Then
		
		LeadCurrentRow = ?(Item.CurrentData = Undefined, Undefined, Item.CurrentData.Ref);
		If LeadCurrentRow <> CurrentLead Then
			CurrentLead = LeadCurrentRow;
			AttachIdleHandler("HandleActivateListRow", 0.2, True);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)
	
	CurrentItem = Items.List;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "Counterparty" Then
		
		Counterparty = CounterpartyRef(SelectedRow);
		
		If NOT ValueIsFilled(Counterparty) Then
			Return;
		EndIf;
		
		StandardProcessing = False;
		FormParameters = New Structure("Key", Counterparty);
		OpenForm("Catalog.Counterparties.ObjectForm", FormParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region KanbanFormTableItemsEventHandlers

&AtClient
Procedure Attachable_KanbanSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Item.CurrentData.Lead);
	
EndProcedure

&AtClient
Procedure Attachable_KanbanOnActivateCell(Item)
	
	If Item.CurrentData <> Undefined Then
		CurrentLead = Item.CurrentData.Lead;
	EndIf;
	ClearActivation(Item.Name);
	
	AttachIdleHandler("HandleActivateKanbanCell", 0.2, True);
	
EndProcedure

&AtClient
Procedure HandleActivateKanbanCell()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtClient
Procedure Attachable_KanbanBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	OpenForm("Catalog.Leads.ObjectForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_KanbanDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If DragParameters.Value.Count() > 0
		AND TypeOf(DragParameters.Value[0]) <> Type("Number") Then
		
		NewActivity = Item.RowFilter.Activity;
		
		LeadsArrayValue = DragParameters.Value;
		LeadsArray = New Array();
		For Each ChangedLead In LeadsArrayValue Do
			ChangeLeadStateAtServer(ChangedLead.Lead, , , NewActivity);
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Kanban(Command)
	
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
Procedure ConvertIntoCustomer()
	
	DontAskUser = DriveReUse.GetValueByDefaultUser(UsersClientServer.CurrentUser(), "ConvertLeadWithoutMessage");
	
	If Not DontAskUser Then
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.DoNotAskAgain = True;
		QuestionParameters.Title = "Lead finalizing";
		
		Notify = New NotifyDescription("ConvertIntoCustomerClickEnd", ThisObject);
		QuestionText = NStr("en = 'Are you sure you want to convert the leads to the customers? This is an irreversible action.'; ru = 'Вы уверены, что хотите перевести лидов в клиенты? Данное действие невозможно будет отменить.';pl = 'Czy na pewno chcesz przekształcić leadów w nabywców? Jest to działanie nieodwracalne.';es_ES = '¿Está seguro de que quiere convertir leads en clientes? Esta acción es irreversible.';es_CO = '¿Está seguro de que quiere convertir leads en clientes? Esta acción es irreversible.';tr = 'Müşteri adaylarını müşterilere dönüştürmek istediğinize emin misiniz? Bu işlem geri alınamaz.';it = 'Siete sicuri di voler convertire i potenziali clienti in clienti? Questa operazione è irreversibile.';de = 'Sind Sie sicher, dass Sie die Leads zu den Kunden umwandeln wollen? Dies ist eine unumkehrbare Handlung.'");
		StandardSubsystemsClient.ShowQuestionToUser(Notify, QuestionText, QuestionDialogMode.OKCancel, QuestionParameters);
		
	Else
		
		Response = New Structure;
		Response.Insert("Value", DialogReturnCode.OK);
		Response.Insert("DoNotAskAgain", False);
		ConvertIntoCustomerClickEnd(Response, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ConvertIntoReject()
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	
	If Items.FormKanban.Check Then
		
		For Each RowID In CurrentItem.SelectedRows Do
			
			NewRejectedLead = ChangedLeads.Add();
			NewRejectedLead.Lead = CurrentItem.Rowdata(RowID).Lead;
			
		EndDo;
		
		If ChangedLeads.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
	If Items.FormList.Check Then
		
		For Each Lead In Items.List.SelectedRows Do
			
			If NOT ValueIsFilled(Lead) Then
				Continue;
			EndIf;
			
			NewRejectedLead = ChangedLeads.Add();
			NewRejectedLead.Lead = Lead;
			
		EndDo;
		
		If ChangedLeads.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
	RejectedLead = New NotifyDescription("DoAfterCloseRejectedLead", ThisObject);
	OpenForm("Catalog.Leads.Form.FormOfRejectedLead",,,,,, RejectedLead, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure PhoneCall(Command)
	
	CreateEventWithContact("PhoneCall", CurrentLead);
	
EndProcedure

&AtClient
Procedure Email(Command)
	
	CreateEventWithContact("Email", CurrentLead);
	
EndProcedure

&AtClient
Procedure SMS(Command)
	
	CreateEventWithContact("SMS", CurrentLead);
	
EndProcedure

&AtClient
Procedure PersonalMeeting(Command)
	
	CreateEventWithContact("PersonalMeeting", CurrentLead);
	
EndProcedure

&AtClient
Procedure Other(Command)
	
	CreateEventWithContact("Other", CurrentLead);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",	New Structure("FullMetadataObjectName, Type", "Leads", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeCampaign(Command)
	
	ClosedLeads = False;
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	FillChangedLeads(ClosedLeads);
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	If ClosedLeads Then
		CommonClientServer.MessageToUser(NStr("en = 'You can''t change finalized leads'; ru = 'Нельзя изменять лиды, работа по которым завершена';pl = 'Nie można zmienić sfinalizowanych leadów';es_ES = 'No puede cambiar leads finalizados';es_CO = 'No puede cambiar leads finalizados';tr = 'Sonuçlandırılmış müşteri adaylarında değişiklik yapamazsınız';it = 'Impossibile modificare Potenziali Clienti finalizzati';de = 'Sie können abgeschlossene Leads nicht ändern.'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.Campaigns.ChoiceForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeActivity(Command)
	
	SelectedCampaign = PredefinedValue("Catalog.Campaigns.EmptyRef");
	ClosedLeads = False;
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	FillChangedLeads(ClosedLeads);
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	If ClosedLeads Then
		CommonClientServer.MessageToUser(NStr("en = 'You can''t change finalized leads'; ru = 'Нельзя изменять лиды, работа по которым завершена';pl = 'Nie można zmienić sfinalizowanych leadów';es_ES = 'No puede cambiar leads finalizados';es_CO = 'No puede cambiar leads finalizados';tr = 'Sonuçlandırılmış müşteri adaylarında değişiklik yapamazsınız';it = 'Impossibile modificare Potenziali Clienti finalizzati';de = 'Sie können abgeschlossene Leads nicht ändern.'"));
		Return;
	EndIf;
	
	// Check one campaign
	If Items.FormKanban.Check Then
		SelectedCampaign = FilterCampaign;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedCampaign = Items.List.RowData(ChangedLeads[0].Lead).Campaign;
		For Each ChangedValue In ChangedLeads Do
			If Items.List.RowData(ChangedValue.Lead).Campaign <> SelectedCampaign Then
				CommonClientServer.MessageToUser(NStr("en = 'To change current activity the leads should be of the same campaign'; ru = 'Для смены вида деятельности лиды должны принадлежать одной кампании.';pl = 'Do zmiany bieżącego działania, leady powinni należeć do tej samej kampanii';es_ES = 'Para cambiar la actividad actual los leads deben ser de la misma empresa';es_CO = 'Para cambiar la actividad actual los leads deben ser de la misma empresa';tr = 'Mevcut faaliyetin değiştirilmesi için müşteri adayları aynı kampanyada olmalıdır ';it = 'Per cambiare la attività corrente i Potenziali Clienti devono essere della stessa campagna';de = 'Um die aktuelle Aktivität zu ändern, sollten die Leads aus der gleichen Kampagne stammen.'"));
				Return;
			EndIf;
		EndDo;
	EndIf;

	ListOfActivities = GetAvailableActivities(SelectedCampaign);
	Notification = New NotifyDescription("AfterActivitiesSelection", ThisObject, SelectedCampaign);
	ListOfActivities.ShowChooseItem(Notification, NStr("en = 'Select new activity.'; ru = 'Выберите новую активность';pl = 'Wybierz nowe działanie.';es_ES = 'Seleccione un nuevo punto de actividad.';es_CO = 'Seleccionar la actividad nueva.';tr = 'Yeni faaliyet seçin.';it = 'Selezionare nuova attività.';de = 'Neue Aktivität auswählen.'"));
	
EndProcedure

&AtClient
Procedure ChangeSalesRep(Command)
	
	ClosedLeads = False;
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	FillChangedLeads(ClosedLeads);
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	If ClosedLeads Then
		CommonClientServer.MessageToUser(NStr("en = 'You can''t change finalized leads'; ru = 'Нельзя изменять лиды, работа по которым завершена';pl = 'Nie można zmienić sfinalizowanych leadów';es_ES = 'No puede cambiar leads finalizados';es_CO = 'No puede cambiar leads finalizados';tr = 'Sonuçlandırılmış müşteri adaylarında değişiklik yapılamaz';it = 'Impossibile modificare Potenziali Clienti finalizzati';de = 'Sie können abgeschlossene Leads nicht ändern.'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.Employees.ChoiceForm", , ThisObject);

EndProcedure

&AtClient
Procedure UpdateKanban(Command)
	GenerateKanban = True;
	UpdateKanbanBoard();
EndProcedure

&AtClient
Procedure Create(Command)
	
	OpenForm("Catalog.Leads.ObjectForm",,ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ConvertIntoCustomerClickEnd(Response, Parameter) Export
	
	If Response.Value = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response.DoNotAskAgain Then
		SetUserSettingAtServer(True, "ConvertLeadWithoutMessage");
	EndIf;
	
	If CheckLeadsSelected() Then
		
		If Items.FormList.Check Then
			DraggedLeads = Items.List.SelectedRows;
		Else
			DraggedLeads = CurrentItem.SelectedRows;
		EndIf;
		
		For Each DragValue In DraggedLeads Do
			
			If Items.FormList.Check Then
				Lead = DragValue;
			Else
				Lead = CurrentItem.Rowdata(DragValue).Lead;
			EndIf;
			
			If ValueIsFilled(Lead) AND CanBeTransferredToClient(Lead) Then
				
				Counterparty = ConvertIntoCustomerAtServer(Lead);
				
				MessageText = NStr("en = 'Lead %1 is converted into customer %2'; ru = 'Лид %1 переведен в клиента %2';pl = 'Lead %1 został przekształcony w nabywcę %2';es_ES = 'El lead %1 se ha convertido al cliente %2';es_CO = 'El lead %1 se ha convertido al cliente %2';tr = '%1 müşteri adayı %2 müşterisine dönüştürüldü';it = 'Il potenziale cliente %1 è stato convertito nel cliente %2';de = 'Lead %1 wird in Kunde %2 umgewandelt'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Lead, Counterparty);
				CommonClientServer.MessageToUser(MessageText, Counterparty);
				
			EndIf;
			
		EndDo;
		
		Notify("Write_Lead");
		
	EndIf;

EndProcedure

&AtServerNoContext
Procedure SetUserSettingAtServer(SettingValue, SettingName)
	DriveServer.SetUserSetting(SettingValue, SettingName, Users.CurrentUser());
EndProcedure

&AtClient
Procedure FillChangedLeads(ClosedLeads)
	
	If Items.FormKanban.Check Then
		
		For Each RowID In CurrentItem.SelectedRows Do
			
			NewChangedLead = ChangedLeads.Add();
			NewChangedLead.Lead = CurrentItem.Rowdata(RowID).Lead;
			
		EndDo;
		
	EndIf;
	
	If Items.FormList.Check Then
		
		For Each Lead In Items.List.SelectedRows Do
			
			If NOT ValueIsFilled(Lead) Then
				Continue;
			EndIf;
			
			NewChangedLead = ChangedLeads.Add();
			NewChangedLead.Lead = Lead;
			
			If Items.ClosureResult.Visible Then
				RowDataLead = Items.List.RowData(Lead);
				If ValueIsFilled(RowDataLead.ClosureResult) Then
					ClosedLeads = True;
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckLeadsSelected()
	
	Result = True;
	
	If Items.FormKanban.Check
		AND (TypeOf(CurrentItem) <> Type("FormTable")
			OR CurrentItem.CurrentData = Undefined
			OR TypeOf(CurrentItem.SelectedRows) <> Type("Array")
			OR CurrentItem.SelectedRows.Count() = 0) Then
		
		Result = False;
		
	ElsIf Items.FormList.Check
		AND (Items.List.CurrentData = Undefined
			OR TypeOf(Items.List.SelectedRows) <> Type("Array")
			OR Items.List.SelectedRows.Count() = 0) Then
			
		Result = False;
		
	EndIf;
	
	If Not Result Then
		
		CommonClientServer.MessageToUser(NStr("en = 'No leads selected'; ru = 'Лиды не выбраны';pl = 'Nie wybrano żadnych leadów';es_ES = 'No hay leads seleccionados';es_CO = 'No hay leads seleccionados';tr = 'Seçilmiş müşteri adayı yok';it = 'Nessun Potenziale Cliente selezionato';de = 'Keine Leads ausgewählt'"));
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure HandleActivateListRow()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtServer
Function CounterpartyRef(SelectedRow)
	
	Return SelectedRow.Counterparty;
	
EndFunction

&AtServer
Function ConvertIntoCustomerAtServer(DraggedItem)
	
	ObjectLead = DraggedItem.GetObject();
	
	NewCounterparty = Catalogs.Leads.GetCreateCounterparty(ObjectLead);
	
	Return NewCounterparty;
	
EndFunction

&AtServer
Procedure ConverIntoRejectedLeadAtServer(RejectedLeadData)
	
	For Each RejectedLead In ChangedLeads Do
		
		Try
			
			DraggedLead = RejectedLead.Lead.GetObject();
			
			DraggedLead.ClosureDate = CurrentSessionDate();
			DraggedLead.ClosureResult = Enums.LeadClosureResult.Rejected;
			DraggedLead.RejectionReason = RejectedLeadData.RejectionReason;
			DraggedLead.ClosureNote = RejectedLeadData.ClosureNote;
			
			DraggedLead.Write();
			
		Except
			CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()), RejectedLead);
			Continue;
		EndTry;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceInCampaignsColorsAtServer()
	
	WorkWithLeads.SetConditionalAppearanceInCampaignsColors(List.SettingsComposer.Settings.ConditionalAppearance);
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Leads);
	FilterItems = CommonClientServer.FindFilterItemsAndGroups(List.SettingsComposer.Settings.Filter, "ClosureResult");
	
	If CanBeEdited Then
		Items.Create.Visible = Items.FormList.Check;
		Items.Copy.Visible = Items.FormList.Check;
		Items.CommonCommandSetReminder.Visible = Items.FormList.Check;	
	EndIf;
	
	Items.CreateKanban.Visible = CanBeEdited AND Items.FormKanban.Check;
	
	Items.SubmenuChange.Visible = CanBeEdited;
	
	Items.ListContextMenuGroupLeadClosure.Visible = CanBeEdited;
	Items.FormGroupLeadClosure.Visible = CanBeEdited;
	
	Items.LeadClosure.Visible = Items.FormKanban.Check;
	Items.LeadClosure.Enabled = CanBeEdited;
	
	Items.GroupKanban.Visible = Items.FormKanban.Check;
	Items.FilterSearch.Visible = Items.FormKanban.Check;
	Items.FormUpdateKanban.Visible = Items.FormKanban.Check;
	Items.FilterCampaign.AutoMarkIncomplete = Items.FormKanban.Check;
	Items.FilterCampaign.MarkIncomplete = Items.FormKanban.Check;
	
	Items.List.Visible = Items.FormList.Check;
	Items.Result.Visible = Items.FormList.Check;
	Items.SearchGroup.Visible = Items.FormList.Check;
	Items.FormGroupCommandsList.Visible = Items.FormList.Check;
	
EndProcedure

&AtServer
Procedure MarkFoDeletionBinDragAtServer(Leads)
	
	For Each Lead In Leads Do
		
		If NOT ValueIsFilled(Lead) Then
			Continue;
		EndIf;
		
		ObjectLead = Lead.Ref.GetObject();
		ObjectLead.DeletionMark = True;
		ObjectLead.Write();
		
	EndDo;
	
EndProcedure

&AtServer
Function CanBeTransferredToClient(Lead)
	
	CanBeTransferredToClient = True;
	
	ObjectLead = Lead.GetObject();
	
	If NOT ObjectLead.CheckFilling() Then
		CanBeTransferredToClient = False;
	EndIf;
	
	Return CanBeTransferredToClient;
		
EndFunction

&AtClient
Procedure CreateEventWithContact(EventTypeName, Lead)
	
	FillingValues = New Structure;
	FillingValues.Insert("EventType", PredefinedValue("Enum.EventTypes." + EventTypeName));
	FillingValues.Insert("Lead", Lead);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceAndUpdateActivityCommands()
	
	SetConditionalAppearanceInCampaignsColorsAtServer();
	
EndProcedure

&AtClient
Procedure DoAfterCloseRejectedLead(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ConverIntoRejectedLeadAtServer(Result);
	
	LeadsArray = New Array;
	For Each Lead In ChangedLeads Do
		LeadsArray.Add(Lead.Lead);
	EndDo;
	Notify("Write_Lead", LeadsArray);
	
	ChangedLeads.Clear();
	
EndProcedure

&AtServerNoContext
Function GetAvailableActivities(Campaign)
	
	Return WorkWithLeads.GetAvailableActivities(Campaign);
	
EndFunction

&AtClient
Procedure AfterActivitiesSelection(SelectedActivity, SelectedCampaign) Export
	
	If SelectedActivity <> Undefined Then
		
		SelectedValue = SelectedActivity.Value;
		LeadsArray = New Array;
		For Each ChangedLead In ChangedLeads Do
			ChangeLeadStateAtServer(ChangedLead.Lead, SelectedCampaign, , SelectedValue);
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ChangeLeadStateAtServer(Lead, Campaign = Undefined, SalesRep = Undefined, Activity = Undefined)
	
	LeadState = WorkWithLeads.LeadState(Lead);
	
	If Campaign <> Undefined Then
		LeadState.Campaign = Campaign;
	EndIf;
	
	If SalesRep <> Undefined Then
		LeadState.SalesRep = SalesRep;
	EndIf;
	
	If Activity <> Undefined Then
		LeadState.Activity = Activity;
	EndIf;
	
	If Not ValueIsFilled(LeadState.Activity) Then
		LeadState.Activity = Catalogs.Campaigns.GetFirstActivity(LeadState.Campaign);
	EndIf;
	
	ObjectLead = Lead.GetObject();
	ObjectLead.AdditionalProperties.Insert("NewState", LeadState);
	ObjectLead.AdditionalProperties.Insert("ActivityHasChanged", True);
	ObjectLead.Write();
	
EndProcedure

#EndRegion

#Region FilterLabel

&AtServer
Procedure SetLabelAndListFilter(ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation = "")
	
	If ValuePresentation = "" Then
		ValuePresentation = String(SelectedValue);
	EndIf;
	
	WorkWithFilters.AttachFilterLabel(ThisObject, ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, ListFilterFieldName,,True);
	
	If Items.FormKanban.Check Then
		UpdateKanbanBoardAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, URLFS, StandardProcessing)
	
	StandardProcessing = False;
		
	LabelID = Mid(Item.Name, StrLen("Label_") + 1);
	
	ActivityLabel = (Item.Parent.Name = "Activities");
	
	DeleteFilterLabel(LabelID);
	
	If Items.FormKanban.Check Then
		If ActivityLabel Then
			GenerateKanban = True;
		EndIf;
		UpdateKanbanBoard();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteFilterLabel(LabelID)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, LabelID);
	
	SetFilterByResult();
	
EndProcedure

&AtServer
Function FilterOptionForSetting()
	
	FormFiltersOption = "";

	Return FormFiltersOption;
	
EndFunction

&AtServer
Procedure SaveFilterSettings()
	
	FormFiltersOption = FilterOptionForSetting();
	WorkWithFilters.SaveFilterSettings(ThisObject,,,FormFiltersOption);
	
	Common.CommonSettingsStorageSave("Filter", "FilterCampaign", FilterCampaign);
	Common.CommonSettingsStorageSave("ViewType", "ViewType_LeadsList", ?(Items.FormList.Check, "List", "Kanban"));
	
EndProcedure

&AtServer
Procedure SetFilterByResult()
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Leads);
	
	FilterItems = CommonClientServer.FindFilterItemsAndGroups(List.SettingsComposer.Settings.Filter, "ClosureResult");
	FirstItem = ?(FilterItems.Count() = 0, Undefined, FilterItems[0]);
	NoSelectionSet = FilterItems.Count() = 0 OR (TypeOf(FirstItem.RightValue) = Type("Array") AND FirstItem.RightValue.Count() = 0);
	IsSelectionSet = Not NoSelectionSet
		AND FilterItems.Count() <> 0
		AND TypeOf(FirstItem.RightValue) = Type("Array")
		AND FirstItem.RightValue.Count() <> 0;
	
	SelectionByActive = IsSelectionSet
		AND FirstItem.RightValue[0] = Enums.LeadClosureResult.EmptyRef();
	
	SelectionByConvertedIntoCustomer = IsSelectionSet 
		AND FirstItem.RightValue[0] = Enums.LeadClosureResult.ConvertedIntoCustomer;
		
	SelectionByRejected = IsSelectionSet
		AND FirstItem.RightValue[0] = Enums.LeadClosureResult.Rejected;
	
	Items.Counterparty.Visible = SelectionByConvertedIntoCustomer OR NoSelectionSet;
	Items.ClosureResult.Visible = SelectionByRejected OR SelectionByConvertedIntoCustomer OR NoSelectionSet;
	Items.RejectionReason.Visible = SelectionByRejected OR NoSelectionSet;
	
	Items.ListContextMenuGroupLeadClosure.Visible = (NoSelectionSet OR SelectionByActive) AND CanBeEdited;
	Items.FormGroupLeadClosure.Visible = Items.ListContextMenuGroupLeadClosure.Visible;
	
	Items.GroupChangeItems.Visible = (NoSelectionSet OR SelectionByActive) AND CanBeEdited;
	
	If SelectionByActive OR SelectionByConvertedIntoCustomer OR SelectionByRejected Then
		
		DriveClientServer.SetListFilterItem(List, "DeletionMark", False, , DataCompositionComparisonType.Equal);
		
	Else
		
		DriveClientServer.DeleteListFilterItem(List, "DeletionMark");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Kanban

#Region KanbanUpdating

&AtClient
Procedure UpdateKanbanBoard()
	
	KanbanTable.Clear();
	
	If ValueIsFilled(FilterCampaign) Then
		
		UpdateKanbanBoardAtServer();
		
		If GenerateKanban Then
			GenerateKanbanColums();
			SetKanbanContextMenu();
			SetKanbanFilter();
			GenerateKanban = False;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateKanbanBoardAtServer()
	
	// Refill table
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CatalogLeads.Ref AS Lead,
	|	CatalogLeads.DeletionMark AS DeletionMark,
	|	CatalogLeads.Code AS Code,
	|	CatalogLeads.AcquisitionChannel AS AcquisitionChannel,
	|	CatalogLeads.BasicInformation AS BasicInformation,
	|	CatalogLeads.ClosureDate AS ClosureDate,
	|	CatalogLeads.ClosureNote AS ClosureNote,
	|	CatalogLeads.ClosureResult AS ClosureResult,
	|	CatalogLeads.Counterparty AS Counterparty,
	|	CatalogLeads.Created AS Created,
	|	CatalogLeads.Note AS Note,
	|	CatalogLeads.Potential AS Potential,
	|	CatalogLeads.RejectionReason AS RejectionReason,
	|	CatalogLeads.KanbanDescription AS Description,
	|	CatalogLeads.Tags.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Tag AS Tag
	|	) AS Tags,
	|	CatalogLeads.Predefined AS Predefined,
	|	CatalogLeads.PredefinedDataName AS PredefinedDataName,
	|	LeadActivitiesSliceLast.Campaign AS Campaign,
	|	LeadActivitiesSliceLast.SalesRep AS SalesRep,
	|	LeadActivitiesSliceLast.Activity AS Activity,
	|	CatalogLeads.Description AS LeadDescription
	|FROM
	|	Catalog.Leads AS CatalogLeads
	|		LEFT JOIN InformationRegister.LeadActivities.SliceLast AS LeadActivitiesSliceLast
	|		ON (LeadActivitiesSliceLast.Lead = CatalogLeads.Ref)
	|WHERE
	|	NOT CatalogLeads.DeletionMark
	|	AND LeadActivitiesSliceLast.Campaign = &Campaign
	|	AND CatalogLeads.ClosureDate = DATETIME(1, 1, 1)
	|	AND &FilterStringKanban
	|
	|ORDER BY
	|	LeadDescription";
	
	Query.SetParameter("Campaign", FilterCampaign);
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
	
	For Each FilterItem In List.SettingsComposer.Settings.Filter.Items Do
		
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		
		If FilterItem.Presentation = "Period" Then
			
			If FilterItem.Items.Count() >= 2 Then
				If FilterItem.Items[0].Use AND FilterItem.Items[1].Use Then
					StringsArray.Add(" AND Created >= &BegDate AND Created <= &EndDate");
					ParametersKanban.Insert("BegDate", FilterItem.Items[0].RightValue);
					ParametersKanban.Insert("EndDate", FilterItem.Items[1].RightValue);
				EndIf;
			EndIf;
			Continue;
			
		EndIf;
		
		If TypeOf(FilterItem.RightValue) = Type("Array") AND FilterItem.RightValue.Count() = 0 Then
			Continue;
		EndIf;
		
		If String(FilterItem.LeftValue) = "Tags.Tag" Then
			StringsArray.Add(" AND Tags.Tag IN (&Tags) ");
			ParametersKanban.Insert("Tags", FilterItem.RightValue);
		ElsIf String(FilterItem.LeftValue) = "SalesRep" Then
			StringsArray.Add(" AND SalesRep IN (&SalesReps) ");
			ParametersKanban.Insert("SalesReps", FilterItem.RightValue);
		ElsIf String(FilterItem.LeftValue) = "AcquisitionChannel" Then
			StringsArray.Add(" AND AcquisitionChannel IN (&AcquisitionChannels) ");
			ParametersKanban.Insert("AcquisitionChannels", FilterItem.RightValue);
		ElsIf String(FilterItem.LeftValue) = "Activity" Then
			StringsArray.Add(" AND Activity IN (&Activities) ");
			ParametersKanban.Insert("Activities", FilterItem.RightValue);
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(FilterSearch) Then
		StringsArray.Add(" AND BasicInformation LIKE &Search ");
		ParametersKanban.Insert("Search", "%" + FilterSearch + "%");
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
		|	CampaignsActivities.Activity AS Activity,
		|	CampaignsActivities.HighlightColor AS Color,
		|	CampaignsActivities.LineNumber AS Order,
		|	Activities.Code AS ActivityCode,
		|	Activities.Description AS ActivityDescription,
		|	""Table_"" + Activities.Code AS ItemTableName,
		|	&KanbanPrefix + ""Group_"" + Activities.Code AS ItemColumnName
		|FROM
		|	Catalog.Campaigns.Activities AS CampaignsActivities
		|		INNER JOIN Catalog.CampaignActivities AS Activities
		|		ON CampaignsActivities.Activity = Activities.Ref
		|WHERE
		|	NOT Activities.DeletionMark
		|	AND &FilterStringKanban
		|
		|ORDER BY
		|	CampaignsActivities.LineNumber";
	
	Query.SetParameter("KanbanPrefix", KanbanPrefix());
	
	FilterStructure = FilterStructureForKanbanColumns();
	Query.Text = StrReplace(Query.Text, "AND &FilterStringKanban", FilterStructure.FilterStringKanban);
	
	For Each FilterKanban In FilterStructure.ParametersKanban Do
		Query.SetParameter(FilterKanban.Key, FilterKanban.Value);
	EndDo;
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	KanbanColumns.Clear();
	
	While SelectionDetailRecords.Next() Do
		
		NewKanbanColumn = KanbanColumns.Add();
		FillPropertyValues(NewKanbanColumn, SelectionDetailRecords);
		NewKanbanColumn.Color = SelectionDetailRecords.Color.Get();
		
	EndDo;
	
EndProcedure

&AtServer
Function FilterStructureForKanbanColumns()
	
	FilterStructure = New Structure("FilterStringKanban, ParametersKanban");
	
	StringsArray = New Array;
	ParametersKanban = New Map;
	
	For Each FilterItem In List.SettingsComposer.Settings.Filter.Items Do
		
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		
		If FilterItem.Presentation = "Period" Then
			Continue;
		EndIf;

		If TypeOf(FilterItem.RightValue) = Type("Array") AND FilterItem.RightValue.Count() = 0 Then
			Continue;
		EndIf;
		
		If String(FilterItem.LeftValue) = "Activity" Then
			StringsArray.Add(" AND Activity IN (&Activities) ");
			ParametersKanban.Insert("Activities", FilterItem.RightValue);
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(FilterCampaign) Then
		StringsArray.Add(" AND CampaignsActivities.Ref = &Campaign ");
		ParametersKanban.Insert("Campaign", FilterCampaign);
	EndIf;
	
	FilterStructure.FilterStringKanban = ?(StringsArray.Count() = 0, "AND TRUE", StrConcat(StringsArray, Chars.LF));
	FilterStructure.ParametersKanban = ParametersKanban;
	
	Return FilterStructure;
	
EndFunction

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
		ItemGroup.Title					= KanbanColumn.ActivityDescription;
		ItemGroup.ToolTip				= KanbanColumn.ActivityDescription;
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
		MainGroupKanbanName				= "TableMainGroup_" + KanbanColumn.ActivityCode;
		MainGroupKanban					= Items.Insert(MainGroupKanbanName, Type("FormGroup"), ItemTable);
		MainGroupKanban.Type			= FormGroupType.ColumnGroup;
		
		// Bottom group
		BottomGroupKanbanName			= "TableBottomGroup_" + KanbanColumn.ActivityCode;
		BottomGroupKanban				= Items.Insert(BottomGroupKanbanName, Type("FormGroup"), MainGroupKanban);
		BottomGroupKanban.Type			= FormGroupType.ColumnGroup;
		
		BottomItemKanbanName			= "TableBottomItem_" + KanbanColumn.ActivityCode;
		BottomItemKanban				= Items.Insert(BottomItemKanbanName, Type("FormField"), BottomGroupKanban);
		BottomItemKanban.Type			= FormFieldType.InputField;
		BottomItemKanban.DataPath		= "KanbanTable.Description";
		BottomItemKanban.Height			= 3;
		
		// Top group
		TopGroupKanbanName				= "TableTopGroup_" + KanbanColumn.ActivityCode;
		TopGroupKanban					= Items.Insert(TopGroupKanbanName, Type("FormGroup"), MainGroupKanban, BottomGroupKanban);
		TopGroupKanban.Type				= FormGroupType.ColumnGroup;
		TopGroupKanban.Group			= ColumnsGroup.InCell;
		
		TopItemKanbanName				= "TableTopItem_" + KanbanColumn.ActivityCode;
		TopItemKanban					= Items.Insert(TopItemKanbanName, Type("FormField"), TopGroupKanban);
		TopItemKanban.Type				= FormFieldType.InputField;
		TopItemKanban.DataPath			= "KanbanTable.Lead";
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
		ChangeStateGroup					= "ChangeStateGroup_" + KanbanColumn.ActivityCode;
		StateGroup							= Items.Add(ChangeStateGroup, Type("FormGroup"), ItemTable.ContextMenu);
		StateGroup.Type						= FormGroupType.ButtonGroup;
		
		ChangeCampaignName					= "CommandChangeCampaign_" + KanbanColumn.ActivityCode;
		CommandChangeCampaign				= Items.Add(ChangeCampaignName, Type("FormButton"), StateGroup);
		CommandChangeCampaign.Title			= NStr("en = 'Change campaign'; ru = 'Изменить кампанию';pl = 'Zmień kampanię';es_ES = 'Cambiar de campaña';es_CO = 'Cambiar de campaña';tr = 'Kampanyayı değiştir';it = 'Modifica campagna';de = 'Kampagne ändern'");
		CommandChangeCampaign.CommandName	= "ChangeCampaign";
		
		ChangeActivityName					= "CommandChangeActivity_" + KanbanColumn.ActivityCode;
		CommandChangeActivity				= Items.Add(ChangeActivityName, Type("FormButton"), StateGroup);
		CommandChangeActivity.Title			= NStr("en = 'Change activity'; ru = 'Изменить активность';pl = 'Zmień działanie';es_ES = 'Cambiar de actividad';es_CO = 'Cambiar de actividad';tr = 'Faaliyeti değiştir';it = 'Modifica attività';de = 'Aktivität ändern'");
		CommandChangeActivity.CommandName	= "ChangeActivity";
		
		ChangeSalesRepName					= "CommandChangeSalesRep_" + KanbanColumn.ActivityCode;
		CommandChangeSalesRep				= Items.Add(ChangeSalesRepName, Type("FormButton"), StateGroup);
		CommandChangeSalesRep.Title			= NStr("en = 'Change sales rep'; ru = 'Изменить представителя компании';pl = 'Zmień przedstawiciela handlowego';es_ES = 'Cambiar de agente de ventas';es_CO = 'Cambiar de agente de ventas';tr = 'Satış temsilcisini değiştir';it = 'Modifica rappresentante di vendita';de = 'Vertriebsmitarbeiter ändern'");
		CommandChangeSalesRep.CommandName	= "ChangeSalesRep";
		
		ConvertIntoCustomerName				= "CommandConvertIntoCustomer_" + KanbanColumn.ActivityCode;
		CommandIntoCustomer					= Items.Add(ConvertIntoCustomerName, Type("FormButton"), ItemTable.ContextMenu);
		CommandIntoCustomer.Title			= NStr("en = 'Convert into customer'; ru = 'Перевести в покупателя';pl = 'Przekształć w nabywcę';es_ES = 'Convertir en cliente';es_CO = 'Convertir en cliente';tr = 'Müşteriye dönüştür';it = 'Converti in cliente';de = 'In Kunde umwandeln'");
		CommandIntoCustomer.CommandName		= "ConvertIntoCustomer";
		
		ConvertIntoRejectName				= "ConvertIntoReject_" + KanbanColumn.ActivityCode;
		CommandIntoReject					= Items.Add(ConvertIntoRejectName, Type("FormButton"), ItemTable.ContextMenu);
		CommandIntoReject.Title				= NStr("en = 'Reject'; ru = 'Отклонить';pl = 'Odrzuć';es_ES = 'Rechazar';es_CO = 'Rechazar';tr = 'Reddet';it = 'Rifiuta';de = 'Ablehnen'");
		CommandIntoReject.CommandName		= "ConvertIntoReject";
		
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

// Activity filter for leads in column
//
&AtClient
Procedure SetKanbanFilter()
	
	For Each Column In KanbanColumns Do
		
		Items[Column.ItemTableName].RowFilter = New FixedStructure("Activity", Column.Activity);
		
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

#EndRegion

#Region ContactInformationPanel

&AtServer
Procedure RefreshContactInformationPanelServer()
	
	Catalogs.Leads.RefreshPanelData(ThisObject, CurrentLead);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ContactInformationPanelClient.ContactInformationPanelDataSelection(ThisObject, Item, SelectedRow, Field, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataOnActivateRow(Item)
	
	ContactInformationPanelClient.ContactInformationPanelDataOnActivateRow(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataExecuteCommand(Command)
	
	ContactInformationPanelClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region ActivitiesChanging

&AtServer
Procedure SetActivityChoiseList(Campaign)
	
	// Clear filter
	DelArray = New Array();
	For Each ChildItem In Items.Activities.ChildItems Do
		If StrFind(ChildItem.Name, "Label_") Then
			LabelID = Mid(ChildItem.Name, StrLen("Label_")+1);
			DelArray.Add(LabelID);
		EndIf;
	EndDo;
	Index = DelArray.Count()-1;
	While Index >= 0 Do
		WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, DelArray[Index]);
		Index = Index - 1;
	EndDo;
	
	// New choice list
	Items.FilterActivity.Enabled = ValueIsFilled(Campaign);
	
	Items.FilterActivity.ChoiceList.Clear();
	ActivitiesChoiceList = GetAvailableActivities(Campaign);
	
	For Each ActivityValue In ActivitiesChoiceList Do
		Items.FilterActivity.ChoiceList.Add(ActivityValue.Value);
	EndDo;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		ShowMessageBox(,NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	Catalogs.Leads.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	
	AttachableCommandsClient.ExecuteCommand(Command, ThisObject, Items.List);
	
EndProcedure

#EndRegion

#EndRegion