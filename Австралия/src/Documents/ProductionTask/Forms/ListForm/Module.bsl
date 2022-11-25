#Region Variables

&AtClient
Var UseProductionTasksInMobileClient;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	OnlyActiveProductionTasks = True;
	
	UseProductionPlanning = GetFunctionalOption("UseProductionPlanning");
	Items.GroupScheduled.Visible = UseProductionPlanning;
	
	FillListAssignee();
	
	// StandardSubsystems.AttachableCommands
	PlacementParameters = AttachableCommands.PlacementParameters();
	Objects = New Array;
	Objects.Add(Metadata.Documents.ProductionTask);
	PlacementParameters.Sources = Objects;
	PlacementParameters.CommandBar = Items.GroupCommandBar;
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If MobileClient Then
		MobileClient = True;
		OnlyActiveProductionTasks = True;
		OnlyMyTask = True;
	#EndIf
	
	UseProductionTasksInMobileClient = UseProductionTasksInMobileClient();
	
	SetFilterStartDate();
	SetFilterDueDate();
	SetFilterDepartment();
	SetFilterAssignee();
	SetFilterProductionOrder();
	SetFilterStatus();
	SetFilterOnlyActiveProductionTasks();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	MobileClientFormManagement();
		
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshProductionOrderQueue" Or EventName = "ProductionTaskStatuseChanged" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If UseProductionTasksInMobileClient And Not Exit Then
		Cancel = True;
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("AfterQueryCloseForExit", ThisObject);
		ShowQueryBox(Notification, NStr("en = 'Do you want to exit the application?'; ru = 'Завершить работу с программой?';pl = 'Czy chcesz zamknąć aplikację?';es_ES = '¿Quiere salir de la aplicación?';es_CO = '¿Quiere salir de la aplicación?';tr = 'Uygulamadan çıkmak istiyor musunuz?';it = 'Uscire dall''applicazione?';de = 'Möchten Sie die Anwendung beenden?'"), Mode, 0);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterDepartmentOnChange(Item)
	
	SetFilterDepartment();
	
EndProcedure

&AtClient
Procedure FilterAssigneeOnChange(Item)
	
	SetFilterAssignee();
	
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
Procedure FilterStatusOnChange(Item)
	
	If OnlyActiveProductionTasks Then
		
		SetFilterOnlyActiveProductionTasks();
		
	Else 
		
		SetFilterStatus();
		
	EndIf; 
	
	
EndProcedure

&AtClient
Procedure OnlyActiveProductionTasksOnChange(Item)
	
	SetFilterOnlyActiveProductionTasks();
	
EndProcedure

&AtClient
Procedure FilterStatusMobileOnChange(Item)
	If OnlyActiveProductionTasks Then
		
		SetFilterOnlyActiveProductionTasks();
		
	Else 
		
		SetFilterStatus();
		
	EndIf;	
EndProcedure

&AtClient
Procedure OnlyMyTaskOnChange(Item)
	SetFilterOnlyMyTask();
EndProcedure

&AtClient
Procedure FilterWorkcenterTypeOnChange(Item)
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"WorkcenterType",
		FilterWorkcenterType,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Workcenter type'; ru = 'Тип рабочего центра';pl = 'Typ gniazda produkcyjnego';es_ES = 'Tipo de centro de trabajo';es_CO = 'Tipo de centro de trabajo';tr = 'İş merkezi türü';it = 'Tipo di centro di lavoro';de = 'Arbeitszentrumtyp'"),
		ValueIsFilled(FilterWorkcenterType));
EndProcedure

&AtClient
Procedure FilterWorkcenterOnChange(Item)
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Workcenter",
		FilterWorkcenter,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Workcenter'; ru = 'Рабочий центр';pl = 'Gniazdo produkcyjne';es_ES = 'Centro de trabajo';es_CO = 'Centro de trabajo';tr = 'İş merkezi';it = 'Centro di lavoro';de = 'Arbeitsabschnittszentrum'"),
		ValueIsFilled(FilterWorkcenter));
EndProcedure

&AtClient
Procedure FilterEndDateOnChange(Item)
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, "EndDateFilter", DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"EndDatePlanned",
		FilterEndDate,
		DataCompositionComparisonType.GreaterOrEqual,
		NStr("en = 'Due date'; ru = 'Срок исполнения';pl = 'Termin';es_ES = 'Fecha de vencimiento';es_CO = 'Fecha de vencimiento';tr = 'Bitiş tarihi';it = 'Data di scadenza';de = 'Fälligkeitsdatum'"),
		ValueIsFilled(FilterEndDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"EndDatePlanned",
		DataCompositionComparisonType.LessOrEqual,
		EndOfDay(FilterEndDate),
		NStr("en = 'Due date'; ru = 'Срок исполнения';pl = 'Termin';es_ES = 'Fecha de vencimiento';es_CO = 'Fecha de vencimiento';tr = 'Bitiş tarihi';it = 'Data di scadenza';de = 'Fälligkeitsdatum'"),
		ValueIsFilled(FilterEndDate));
		
EndProcedure

&AtClient
Procedure FilterProductsOnChange(Item)
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Products",
		FilterProducts,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Products'; ru = 'Номенклатура';pl = 'Produkty';es_ES = 'Productos';es_CO = 'Productos';tr = 'Ürünler';it = 'Articoli';de = 'Produkte'"),
		ValueIsFilled(FilterProducts));
		
EndProcedure

&AtClient
Procedure FilterComponentsOnChange(Item)
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"ComponentsList",
		String(FilterComponents),
		DataCompositionComparisonType.Contains,
		NStr("en = 'Components'; ru = 'Сырье и материалы';pl = 'Komponenty';es_ES = 'Componentes';es_CO = 'Componentes';tr = 'Malzemeler';it = 'Componenti';de = 'Komponenten'"),
		ValueIsFilled(FilterComponents));
		
EndProcedure

&AtClient
Procedure FilterPriorityOnChange(Item)
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Priority",
		FilterPriority,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Priority'; ru = 'Приоритет';pl = 'Priorytet';es_ES = 'Prioridad';es_CO = 'Prioridad';tr = 'Öncelik';it = 'Priorità';de = 'Priorität'"),
		ValueIsFilled(FilterPriority));
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductionOrder" Then
		
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.ProductionOrder);
		
	ElsIf Field.Name = "WorkInProgress" Then
		
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.WorkInProgress);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

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

&AtClient
Procedure SetFilterDepartment()
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
Procedure SetFilterAssignee()
	DriveClientServer.SetListFilterItem(List, "Assignee", FilterAssignee, ValueIsFilled(FilterAssignee));
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
		"StartDatePlanned",
		FilterStartDate.StartDate,
		DataCompositionComparisonType.GreaterOrEqual,
		NStr("en = 'Start date'; ru = 'Дата начала';pl = 'Data początkowa';es_ES = 'Fecha de inicio';es_CO = 'Fecha de inicio';tr = 'Başlangıç tarihi';it = 'Data d''inizio';de = 'Startdatum'"),
		ValueIsFilled(FilterStartDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"StartDatePlanned",
		DataCompositionComparisonType.LessOrEqual,
		FilterStartDate.EndDate,
		NStr("en = 'Start date'; ru = 'Дата начала';pl = 'Data początkowa';es_ES = 'Fecha de inicio';es_CO = 'Fecha de inicio';tr = 'Başlangıç tarihi';it = 'Data d''inizio';de = 'Startdatum'"),
		ValueIsFilled(FilterStartDate));

EndProcedure

&AtClient
Procedure SetFilterDueDate()
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, "DueDateFilter", DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"EndDatePlanned",
		FilterDueDate.StartDate,
		DataCompositionComparisonType.GreaterOrEqual,
		NStr("en = 'Due date'; ru = 'Срок';pl = 'Termin';es_ES = 'Fecha de vencimiento';es_CO = 'Fecha de vencimiento';tr = 'Bitiş tarihi';it = 'Data di scadenza';de = 'Fälligkeitsdatum'"),
		ValueIsFilled(FilterDueDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"EndDatePlanned",
		DataCompositionComparisonType.LessOrEqual,
		FilterDueDate.EndDate,
		NStr("en = 'Due date'; ru = 'Срок';pl = 'Termin';es_ES = 'Fecha de vencimiento';es_CO = 'Fecha de vencimiento';tr = 'Bitiş tarihi';it = 'Data di scadenza';de = 'Fälligkeitsdatum'"),
		ValueIsFilled(FilterDueDate));

EndProcedure

&AtClient
Procedure SetFilterStatus()
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Status",
		FilterStatus,
		DataCompositionComparisonType.Equal,
		NStr("en = 'Status'; ru = 'Статус';pl = 'Status';es_ES = 'Estado';es_CO = 'Estado';tr = 'Durum';it = 'Stato';de = 'Status'"),
		ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure SetFilterOnlyActiveProductionTasks()
	
	StatusesArray = New Array;
	StatusesArray.Add(PredefinedValue("Enum.ProductionTaskStatuses.InProgress"));
	StatusesArray.Add(PredefinedValue("Enum.ProductionTaskStatuses.Open"));
	StatusesArray.Add(PredefinedValue("Enum.ProductionTaskStatuses.Suspended"));
	
	Items.FilterStatus.ListChoiceMode = OnlyActiveProductionTasks;
	Items.FilterStatus.ChoiceList.LoadValues(New Array);
	If OnlyActiveProductionTasks Then
		Items.FilterStatus.ChoiceList.LoadValues(StatusesArray);
	EndIf;
	
	Items.FilterStatusMobile.ListChoiceMode = OnlyActiveProductionTasks;
	Items.FilterStatusMobile.ChoiceList.LoadValues(New Array);
	If OnlyActiveProductionTasks Then
		Items.FilterStatusMobile.ChoiceList.LoadValues(StatusesArray);
	EndIf;
	
	IsFunnel = False;
	
	If OnlyActiveProductionTasks
		And StatusesArray.Find(FilterStatus) = Undefined Then
		
		FilterStatus = PredefinedValue("Enum.ProductionTaskStatuses.EmptyRef");
		SetFilterStatus();
		
	ElsIf OnlyActiveProductionTasks
		And StatusesArray.Find(FilterStatus) <> Undefined Then
		
		IsFunnel = True;
		
		ArrayFunnel = New Array;
		ArrayFunnel.Add(FilterStatus);
		
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Status",
		?(IsFunnel, ArrayFunnel, StatusesArray),
		DataCompositionComparisonType.InList,
		NStr("en = 'Only active tasks'; ru = 'Только активные задачи';pl = 'Tylko aktywne zadania';es_ES = 'Sólo las tareas activas';es_CO = 'Sólo las tareas activas';tr = 'Sadece aktif görevler';it = 'Solo compiti attivi';de = 'Nur aktive Aufgaben'"),
		OnlyActiveProductionTasks);
		
	If Not OnlyActiveProductionTasks
		And ValueIsFilled(FilterStatus) Then
		SetFilterStatus();
	EndIf;
	
EndProcedure

#Region MobileClient

&AtClient
Procedure MobileClientFormManagement()
	
	If MobileClient Then

		SetMobileItemsVisibility();
		SetConditionalAppearanceMobileClient();
		SetFilterOnlyMyTask();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetMobileItemsVisibility()
		
	#If MobileClient Then
		
		For Each ItemList In Items.List.ChildItems Do
			If ItemList.DisplayImportance = DisplayImportance.VeryLow Then
				ItemList.Visible = False;
			EndIf;
		EndDo;
		
		For Each ItemList In Items.GroupCommandBar.ChildItems Do
			If ItemList.DisplayImportance <> DisplayImportance.VeryHigh Then
				ItemList.Visible = False;
			EndIf;
		EndDo;
		
	#EndIf
	
	For Each ItemList In Items.List.ContextMenu.ChildItems Do
		ItemList.Visible = False;
	EndDo;
	
	Items.MobileFilter.Visible						    = True;
	Items.QuickFilters.Visible 							= False;
	Items.ListDocumentProductionTaskSplitMobile.Visible = True;
	Items.Components.Visible 							= True;
	Items.ListDocumentProductionTaskToMe.Visible 		= True;
	Items.ListDocumentProductionTaskToMyTeam.Visible 	= IsUserIncludedInAnyTeam();
	Items.RefreshMobileClient.Visible 					= True;
	Items.StatusLegend.Visible 							= True;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceMobileClient()
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		ItemAppearance.Filter.Items,
		"OpenStatusProgress",
		DataCompositionFilterItemsGroupType.AndGroup);
	
	DataFilterItem					= FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.Status");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= PredefinedValue("Enum.ProductionTaskStatuses.Open");
	DataFilterItem.Use				= True;
	
	DataFilterItem					= FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.CanBeStarted");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", StyleColors.ProductionTaskColorPaleGreen);
	
	FieldAppearance 				= ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field 			= New DataCompositionField("List");
	FieldAppearance.Use 			= True;
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.Status");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= PredefinedValue("Enum.ProductionTaskStatuses.InProgress");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", StyleColors.ProductionTaskColorSandyBrown);
	
	FieldAppearance 				= ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field 			= New DataCompositionField("List");
	FieldAppearance.Use 			= True;
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.Status");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= PredefinedValue("Enum.ProductionTaskStatuses.Suspended");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", StyleColors.ProductionTaskColorLightCoral);
	
	FieldAppearance 				= ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field 			= New DataCompositionField("List");
	FieldAppearance.Use 			= True;
	
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(ItemAppearance.Filter.Items, "OpenStatusNotProgress", DataCompositionFilterItemsGroupType.AndGroup);
	
	DataFilterItem					= FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.Status");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= PredefinedValue("Enum.ProductionTaskStatuses.Open");
	DataFilterItem.Use				= True;
	
	DataFilterItem					= FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.CanBeStarted");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", StyleColors.ProductionTaskColorGainsboro);
	
	FieldAppearance 				= ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field 			= New DataCompositionField("List");
	FieldAppearance.Use 			= True;
	
EndProcedure

#EndRegion

&AtServer
Procedure FillListAssignee()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	UserEmployees.Employee AS Employee
	|INTO TT_UserEmployees
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|WHERE
	|	UserEmployees.User = &User
	|	AND UserEmployees.Employee <> VALUE(Catalog.Employees.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_UserEmployees.Employee AS Employee
	|FROM
	|	TT_UserEmployees AS TT_UserEmployees
	|
	|UNION ALL
	|
	|SELECT
	|	TeamsContent.Ref
	|FROM
	|	TT_UserEmployees AS TT_UserEmployees
	|		INNER JOIN Catalog.Teams.Content AS TeamsContent
	|		ON TT_UserEmployees.Employee = TeamsContent.Employee
	|
	|GROUP BY
	|	TeamsContent.Ref";
	
	Query.SetParameter("User", Users.CurrentUser());
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	While SelectionDetailRecords.Next() Do
		ListAssignee.Add(SelectionDetailRecords.Employee);
	EndDo;

EndProcedure

&AtClient
Procedure SetFilterOnlyMyTask()
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Assignee",
		ListAssignee,
		DataCompositionComparisonType.InList,
		NStr("en = 'Assignee'; ru = 'Исполнитель';pl = 'Wykonawca';es_ES = 'Beneficiario';es_CO = 'Beneficiario';tr = 'Atanan';it = 'Assegnatario';de = 'Beauftragte'"),
		OnlyMyTask);
		
EndProcedure

&AtClient
Procedure AfterQueryCloseForExit(Result, Parameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Exit(False);
	
EndProcedure

&AtServerNoContext
Function UseProductionTasksInMobileClient()
	
	Result = False;
	
	#If MobileClient Then
		Result = Users.RolesAvailable("UseProductionTasksInMobileClient");
	#EndIf
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function IsUserIncludedInAnyTeam()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	UserEmployees.Employee AS Employee
	|INTO TT_UserEmployees
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|WHERE
	|	UserEmployees.User = &User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TeamsContent.Ref AS Ref
	|FROM
	|	TT_UserEmployees AS TT_UserEmployees
	|		INNER JOIN Catalog.Teams.Content AS TeamsContent
	|		ON TT_UserEmployees.Employee = TeamsContent.Employee";
	
	Query.SetParameter("User", Users.CurrentUser());
	
	QueryResult = Query.Execute();
	
	Return (Not QueryResult.IsEmpty());
	
EndFunction

#EndRegion

