#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	UseProductionTask = GetFunctionalOption("UseProductionTask")
		And AccessRight("Edit", Metadata.Documents.ProductionTask);
	
	OnlyActive = true;
	
	SetByVisible();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
	SetFilterStartDate();
	SetFilterDueDate();
	SetFilterScheduledDueDate();
	SetFilterDepartment();
	SetFilterProductionOrder();
	SetFilterWorkCenterType();
	SetFilterStatus();
	SetFilterForCreatingProductionTasks();
	SetFilterForClosing();
	SetFilterOverdue();
	SetFilterOnlyActive();
	SetFilterOutput();
	SetFilterProductionMethod();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshProductionOrderQueue" Or EventName = "ProductionTaskStatuseChanged" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = NOT Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

&AtClient
Procedure FilterDepartmentOnChange(Item)
	SetFilterDepartment();
EndProcedure

&AtClient
Procedure FilterProductionOrderOnChange(Item)
	SetFilterProductionOrder();
EndProcedure

&AtClient
Procedure FilterStartDateOnChange(Item)
	SetFilterStartDate();
EndProcedure

&AtClient
Procedure FilterDueDateOnChange(Item)
	SetFilterDueDate();
EndProcedure

&AtClient
Procedure FilterScheduledDueDateOnChange(Item)
	SetFilterScheduledDueDate();
EndProcedure

&AtClient
Procedure FilterWorkCenterTypeOnChange(Item)
	SetFilterWorkCenterType();
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	SetFilterStatus();
EndProcedure

&AtClient
Procedure FilterForCreatingProductionTasksOnChange(Item)
	SetFilterForCreatingProductionTasks();
EndProcedure

&AtClient
Procedure FilterForClosingOnChange(Item)
	SetFilterForClosing();
EndProcedure

&AtClient
Procedure FilterOverdueOnChange(Item)
	SetFilterOverdue();
EndProcedure

&AtClient
Procedure FilterOutputOnChange(Item)
	SetFilterOutput();
EndProcedure

&AtClient
Procedure FilterProductionMethodOnChange(Item)
	SetFilterProductionMethod();
EndProcedure

&AtClient
Procedure OnlyActiveOnChange(Item)
	
	SetFilterOnlyActive();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductionOrder" Then
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.ProductionOrder);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenProductionOrderQueueManagement(Command)
	
	OpenForm("DataProcessor.ProductionOrderQueueManagement.Form.Form");
	
EndProcedure

&AtClient
Procedure OpenProductionTaskManagement(Command)
	
	OpenForm("Document.ProductionTask.ListForm");
	
EndProcedure

&AtClient
Procedure CompleteWorkInProgress(Command)
	
	WIPsArray = Items.List.SelectedRows;
	
	Checked = True;
	
	For Each WIP In WIPsArray Do
		
		RowData = Items.List.RowData(WIP);
		
		If RowData.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed") Then
			
			Checked = False;
			MessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been completed.'; ru = '%1 уже завершено.';pl = '%1 został już wykonany.';es_ES = '%1 ya ha sido completado.';es_CO = '%1 ya ha sido completado.';tr = '%1 zaten tamamlandı.';it = '%1 è già stato completato.';de = '%1 wurde bereits abgeschlossen.'"),
				WIP);
			CommonClientServer.MessageToUser(MessageToUser);
			
		EndIf;
		
	EndDo;
	
	If Checked Then
		
		CurrentDate = CurrentDateAtServer();
		
		AddParameter = New Structure("WIPsArray", WIPsArray);
		ShowInputDate(
			New NotifyDescription("CompleteWIPFillInDate", ThisObject, AddParameter),
			CurrentDate,
			NStr("en = 'End date and time'; ru = 'Дата и время завершения';pl = 'Data i czas zakończenia';es_ES = 'Fecha y hora final';es_CO = 'Fecha y hora final';tr = 'Bitiş tarihi ve saati';it = 'Data e ora fine';de = 'Enddatum und -zeit'"),
			DateFractions.DateTime);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	Items.GroupTasksFilters.Visible = UseProductionTask;
	Items.AccomplishmentStatus.Visible = UseProductionTask;
	Items.StatusLegend.Visible = UseProductionTask;
	
EndProcedure

&AtServerNoContext
Function CurrentDateAtServer()
	
	Return CurrentSessionDate();
	
EndFunction

&AtClient
Procedure CompleteWIPFillInDate(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		CompleteWorkInProgressAtServer(AdditionalParameters.WIPsArray, Result);
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CompleteWorkInProgressAtServer(WIPsArray, FinishDate)

	For Each WIP In WIPsArray Do
		
		WIPObject = WIP.GetObject();
		WIPObject.CompleteWorkInProgress(FinishDate);
		
		Try
			
			WIPObject.Write(DocumentWriteMode.Posting);
			
		Except
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot change the document %1: %2'; ru = 'Невозможно изменить документ %1: %2';pl = 'Nie można zmienić dokumentu %1: %2';es_ES = 'No se ha podido cambiar el documento %1: %2';es_CO = 'No se ha podido cambiar el documento %1: %2';tr = '%1 belgesi değiştirilemiyor: %2';it = 'Impossibile modificare il documento %1: %2';de = 'Das Dokument %1 kann nicht geändert werden: %2'"),
				WIP,
				BriefErrorDescription(ErrorInfo()));
			CommonClientServer.MessageToUser(MessageText);
			
		EndTry;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = List.ConditionalAppearance.Items.Add();
	NewConditionalAppearance.Presentation = NStr("en = 'Overdue'; ru = 'Просрочено';pl = 'Zaległe';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi geçmiş';it = 'In ritardo';de = 'Überfällig'");
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Finish",
		BegOfDay(CurrentSessionDate()),
		DataCompositionComparisonType.Less);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Status",
		Enums.ManufacturingOperationStatuses.Completed,
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "Finish");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", WebColors.DarkRed);
	
EndProcedure

&AtClient
Procedure SetFilterDepartment()
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
Procedure SetFilterProductionOrder()
	DriveClientServer.SetListFilterItem(List, "ProductionOrder", FilterProductionOrder, ValueIsFilled(FilterProductionOrder));
EndProcedure

&AtClient
Procedure SetFilterStartDate()
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, "StartDateFilter", DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Start",
		FilterStartDate.StartDate,
		DataCompositionComparisonType.GreaterOrEqual,
		"StartDate",
		ValueIsFilled(FilterStartDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"Start",
		DataCompositionComparisonType.LessOrEqual,
		FilterStartDate.EndDate,
		"EndDate",
		ValueIsFilled(FilterStartDate));

EndProcedure

&AtClient
Procedure SetFilterDueDate()
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, "DueDateFilter", DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Finish",
		FilterDueDate.StartDate,
		DataCompositionComparisonType.GreaterOrEqual,
		"StartDate",
		ValueIsFilled(FilterDueDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"Finish",
		DataCompositionComparisonType.LessOrEqual,
		FilterDueDate.EndDate,
		"EndDate",
		ValueIsFilled(FilterDueDate));

EndProcedure

&AtClient
Procedure SetFilterScheduledDueDate()
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, "ScheduledDueDate", DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"StartDateBySchedule",
		Undefined,
		DataCompositionComparisonType.Filled,
		"StartDateIsFilled",
		ValueIsFilled(FilterScheduledDueDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"StartDateBySchedule",
		DataCompositionComparisonType.LessOrEqual,
		FilterScheduledDueDate.Date,
		"StartDateFilter",
		ValueIsFilled(FilterScheduledDueDate));

EndProcedure

&AtClient
Procedure SetFilterWorkCenterType()
	
	DriveClientServer.SetListFilterItem(
		List,
		"WorkCenterTypes",
		TrimAll(FilterWorkCenterType),
		ValueIsFilled(FilterWorkCenterType),
		DataCompositionComparisonType.Contains);
	
EndProcedure

&AtClient
Procedure SetFilterStatus()
	
	If ValueIsFilled(FilterStatus) Then
		
		If FilterOverdue Then
			FilterOverdue = False;
			SetFilterOverdue();
		EndIf;
		
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Status",
		FilterStatus,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Status'; ru = 'Статус';pl = 'Status';es_ES = 'Estatus';es_CO = 'Estatus';tr = 'Durum';it = 'Stato';de = 'Status'"),
		ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure SetFilterForCreatingProductionTasks();
	
	// In progress and quantity < 0
	
	If FilterForCreatingProductionTasks Then
		
		If FilterForClosing Then
			FilterForClosing = False;
			SetFilterForClosing();
		EndIf;
		
	EndIf;
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		SetElements,
		NStr("en = 'For creating Production Tasks'; ru = 'Для создания производственных задач';pl = 'Do utworzenia Zadań produkcyjnych';es_ES = 'Para crear tareas de producción';es_CO = 'Para crear tareas de producción';tr = 'Üretim Görevleri oluşturmak için';it = 'Per la creazione di Incarichi di produzione';de = 'Für Erstellen von Produktionsaufgaben'"),
		DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"AccomplishmentBalance",
		0,
		DataCompositionComparisonType.Less,
		NStr("en = 'Not all tasks created'; ru = 'Созданы не все задачи';pl = 'Utworzono nie wszystkie zadania';es_ES = 'No se han creado todas las tareas';es_CO = 'No se han creado todas las tareas';tr = 'Tüm görevler oluşturulmadı';it = 'Non tutti gli incarichi creati';de = 'Nicht alle Aufgaben erstellt'"),
		FilterForCreatingProductionTasks);
		
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Status",
		PredefinedValue("Enum.ManufacturingOperationStatuses.Completed"),
		DataCompositionComparisonType.NotEqual,
		NStr("en = 'Not completed'; ru = 'Не завершенные';pl = 'Nie zakończone';es_ES = 'No se ha completado';es_CO = 'No se ha completado';tr = 'Tamamlanmadı';it = 'Non completato';de = 'Nicht abgeschlossen'"),
		FilterForCreatingProductionTasks);
	
EndProcedure

&AtClient
Procedure SetFilterForClosing();
	
	// In progress and Quantity produced >= 0
	
	If FilterForClosing Then
		
		If FilterForCreatingProductionTasks Then
			FilterForCreatingProductionTasks = False;
			SetFilterForCreatingProductionTasks();
		EndIf;
		
	EndIf;
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		SetElements,
		NStr("en = 'For closing'; ru = 'Для закрытия';pl = 'Do zamknięcia';es_ES = 'Para cerrar';es_CO = 'Para cerrar';tr = 'Kapatmak için';it = 'Per chiusura';de = 'Zum Schließen'"),
		DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"AccomplishmentProducedBalance",
		0,
		DataCompositionComparisonType.GreaterOrEqual,
		NStr("en = 'All tasks finished'; ru = 'Все задачи завершены';pl = 'Zakończono wszystkie zadania';es_ES = 'Se han terminado todas las tareas';es_CO = 'Se han terminado todas las tareas';tr = 'Tüm görevler tamamlandı';it = 'Tutti gli incarichi sono ultimati';de = 'Alle Aufgaben abgeschlossen'"),
		FilterForClosing);
		
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Status",
		PredefinedValue("Enum.ManufacturingOperationStatuses.Completed"),
		DataCompositionComparisonType.NotEqual,
		NStr("en = 'Not completed'; ru = 'Не завершенные';pl = 'Nie zakończone';es_ES = 'No se ha completado';es_CO = 'No se ha completado';tr = 'Tamamlanmadı';it = 'Non completato';de = 'Nicht abgeschlossen'"),
		FilterForClosing);
	
EndProcedure

&AtClient
Procedure SetFilterOverdue()
	
	If FilterOverdue Then
		
		If ValueIsFilled(FilterStatus) Then
			FilterStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.EmptyRef");
			SetFilterStatus();
		EndIf;
		
	EndIf;
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, NStr("en = 'Overdue'; ru = 'Просрочено';pl = 'Zaległe';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi geçmiş';it = 'In ritardo';de = 'Überfällig'"), DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Finish",
		BegOfDay(CommonClient.SessionDate()),
		DataCompositionComparisonType.Less,
		NStr("en = 'Later then current date'; ru = 'Позже, чем текущая дата';pl = 'Później niż niniejsza data';es_ES = 'Después de la fecha actual';es_CO = 'Después de la fecha actual';tr = 'Güncel tarihten sonra';it = 'Successivo alla data corrente';de = 'Später als aktuelles Datum'"),
		FilterOverdue);
		
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Status",
		PredefinedValue("Enum.ManufacturingOperationStatuses.Completed"),
		DataCompositionComparisonType.NotEqual,
		NStr("en = 'Not completed'; ru = 'Не завершено';pl = 'Nie zakończone';es_ES = 'No se ha completado';es_CO = 'No se ha completado';tr = 'Tamamlanmadı';it = 'Non completato';de = 'Nicht abgeschlossen'"),
		FilterOverdue);
	
EndProcedure

&AtClient
Procedure SetFilterOnlyActive()
	
	If OnlyActive
		And FilterStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed") Then
		
		FilterStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.EmptyRef");
		SetFilterStatus();
		
	EndIf;
	
	List.Parameters.SetParameterValue("OnlyActive", OnlyActive);
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure SetFilterOutput()
	
	DriveClientServer.SetListFilterItem(List, "Output", FilterOutput, FilterOutput);
	
EndProcedure

&AtClient
Procedure SetFilterProductionMethod()
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"ProductionMethod",
		FilterProductionMethod,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Production method'; ru = 'Способ производства';pl = 'Sposób produkcji';es_ES = 'Método de producción';es_CO = 'Método de producción';tr = 'Üretim yöntemi';it = 'Metodo di produzione';de = 'Produktionsmethode'"),
		ValueIsFilled(FilterProductionMethod));
	
EndProcedure

&AtServer
Procedure SetByVisible()

	UseProductionPlanning = GetFunctionalOption("UseProductionPlanning");
	
	Items.GroupBySchedule.Visible = UseProductionPlanning;
	
	UseSubcontractorPlanning = GetFunctionalOption("CanReceiveSubcontractingServices");
	
	Items.FilterProductionMethod.Visible = UseSubcontractorPlanning;
	Items.ProductionMethod.Visible		 = UseSubcontractorPlanning;
	
	HasSubcontractingRights = False;
	If UseSubcontractorPlanning Then
		HasSubcontractingRights = AccessRight("Edit", Metadata.Documents.SubcontractorOrderIssued);
	EndIf;
	
	Items.GenerateSubcontractorOrderIssued.Visible = HasSubcontractingRights;
	
EndProcedure

&AtClient
Procedure GenerateSubcontractorOrderIssued(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FormParameters = New Structure("Basis", CurrentData.Ref);
		OpenForm("Document.SubcontractorOrderIssued.Form.DocumentForm",
			FormParameters);
		
	EndIf;

EndProcedure

#EndRegion

