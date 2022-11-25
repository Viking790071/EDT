#Region Variables

&AtServer
Var DisplayedUserTasksAndSections;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		// Return when a form is received for analysis.
		Return;
	EndIf;
	
	TaxiInterface = (ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Taxi);
	
	TimeConsumingOperation = GenerateToDoListInBackground();
	LoadAutoRefreshSettings();
	
	Items.FormCustomize.Enabled = False;
	Items.FormRefresh.Enabled  = (TimeConsumingOperation = Undefined);
	Items.FormCustomize.Visible   = AccessRight("SaveUserData", Metadata);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TimeConsumingOperation <> Undefined Then
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.Interval = 2; // Faster than a standard interval as it is shown on the home page.
		CompletionNotification = New NotifyDescription("GenerateToDoListInBackgroundCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ToDoList_AutoUpdateEnabled" Then
		LoadAutoRefreshSettings();
		UpdatePeriod = AutoUpdateSettings.AutoRefreshPeriod * 60;
		AttachIdleHandler("UpdateCurrentToDosAutomatically", UpdatePeriod);
	ElsIf EventName = "ToDoList_AutoUpdateDisabled" Then
		DetachIdleHandler("UpdateCurrentToDosAutomatically");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	DetachIdleHandler("UpdateCurrentToDosAutomatically");
	If Exit Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormControlItemsEventHandlers

&AtClient
Procedure Attachable_ProcessHyperlinkClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ClosingNotification = New NotifyDescription("ProcessHyperlinkClickCompletion", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("ID", Item.Name);
	UserTaskParameters = UserTasksParameters.FindRows(FilterParameters)[0];
	
	OpenForm(UserTaskParameters.Form, UserTaskParameters.FormParameters, ThisObject,,,, ClosingNotification);
	
EndProcedure

&AtClient
Procedure Attachable_URLClickProcessing(Item, Ref, StandardProcessing)
	
	StandardProcessing = False;
	
	ClosingNotification = New NotifyDescription("ProcessHyperlinkClickCompletion", ThisObject);
	
	FilterParameters = New Structure();
	FilterParameters.Insert("ID", Ref);
	UserTaskParameters = UserTasksParameters.FindRows(FilterParameters)[0];
	
	OpenForm(UserTaskParameters.Form, UserTaskParameters.FormParameters ,,,,, ClosingNotification);
	
EndProcedure

&AtClient
Procedure Attachable_ProcessPictureClick(Item)
	SwitchPicture(Item.Name);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetUp(Command)
	
	ResultHandler = New NotifyDescription("ApplyToDoListPanel", ThisObject);
	
	FormParameters = New Structure;
	FormParameters.Insert("ToDoList", UserTasksToStorage);
	OpenForm("DataProcessor.ToDoList.Form.CustomizeCurrentUserTasks", FormParameters,,,,,ResultHandler);
	
EndProcedure

&AtClient
Procedure Update(Command)
	StartToDoListUpdate();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of generating a user's to-do list.

&AtClient
Procedure UpdateCurrentToDosAutomatically()
	StartToDoListUpdate(True);
EndProcedure

&AtServer
Procedure RefreshToDoList(ToDoList)
	
	ToDoList.Sort("IsSection Desc, SectionPresentation Asc, Important Desc");
	
	PutToTempStorage(ToDoList, UserTasksToStorage);
	
	SectionsWithImportantUserTasks = New Structure;
	SavedViewSettings = ToDoListInternal.SavedViewSettings();
	If SavedViewSettings = Undefined Then
		SectionsVisibleSet = New Map;
		UserTasksVisibleSet      = New Map;
	Else
		SectionsVisibleSet = SavedViewSettings.SectionsVisibility;
		UserTasksVisibleSet      = SavedViewSettings.UserTasksVisible;
	EndIf;
	CollapsedSections = CollapsedSections();
	
	CurrentSection = "";
	UserTasksParameters.Clear();
	For Each UserTask In ToDoList Do
		
		If UserTask.IsSection Then
			// Reset section visibility. It is set from a to-do.
			SectionName = "CommonGroup" + UserTask.OwnerID;
			GroupCollapsingPictureName = "Picture" + UserTask.OwnerID;
			If SectionName <> CurrentSection Then
				ParentElement = Items.Find(SectionName);
				If ParentElement = Undefined Then
					Continue;
				EndIf;
				ParentElement.Visible = False;
				// Reset value of an indicator showing whether there are important to-dos.
				If Items[GroupCollapsingPictureName].Picture = PictureLib.RedRightArrow Then
					Items[GroupCollapsingPictureName].Picture = PictureLib.RightArrow;
				EndIf;
			EndIf;
			// Refresh a to-do.
			RefreshUserTask(UserTask, ParentElement, SectionsVisibleSet, UserTasksVisibleSet);
			
			// Enable an indicator showing whether there are important to-dos.
			If UserTask.HasUserTasks
				AND UserTask.Important
				AND UserTasksVisibleSet[UserTask.ID] <> False Then
				SectionsWithImportantUserTasks.Insert(UserTask.OwnerID, CollapsedSections[UserTask.OwnerID]);
			EndIf;
			
			CurrentSection = SectionName;
		Else
			// Child to-dos are created again.
			NewChildUserTask(UserTask);
		EndIf;
		FillUserTaskParameters(UserTask);
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshUserTask(UserTask, UserTaskParent, SectionsVisibleSet, UserTasksVisibleSet)
	
	SectionVisibleEnabled = SectionsVisibleSet[UserTask.OwnerID];
	If SectionVisibleEnabled = Undefined Then
		SectionVisibleEnabled = True;
	EndIf;
	UserTaskVisibleEnabled = UserTasksVisibleSet[UserTask.ID];
	If UserTaskVisibleEnabled = Undefined Then
		UserTaskVisibleEnabled = True;
	EndIf;
	
	Item = Items.Find(UserTask.ID);
	If Item = Undefined Then
		// The to-do is not in the list. It probably was created after enabling the functional option. It 
		// will be added it in this case.
		UserTaskGroupName = StrReplace(UserTaskParent.Name, "CommonGroup", "Group");
		UserTaskGroup = UserTaskParent.ChildItems.Find(UserTaskGroupName);
		NewUserTask(UserTask, UserTaskGroup, UserTaskVisibleEnabled);
		Return;
	EndIf;
	
	UserTaskTitle = UserTask.Presentation + ?(UserTask.Count <> 0," (" + UserTask.Count + ")", "");
	Item.Title = UserTaskTitle;
	If UserTask.Important Then
		Item.TextColor = StyleColors.OverdueDataColor;
	EndIf;
	Item.Visible = UserTask.HasUserTasks AND UserTaskVisibleEnabled;
	// Reset child to-dos, if any. They will be updated later.
	Item.ExtendedToolTip.Title = "";
	
	// Set a tooltip, if specified.
	If ValueIsFilled(UserTask.ToolTip) Then
		Tooltip                    = New FormattedString(UserTask.ToolTip);
		Item.ToolTip            = Tooltip;
		Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
	// Set section visibility.
	If Item.Visible AND SectionVisibleEnabled Then
		SectionTitle = StrReplace(UserTaskParent.Name, "CommonGroup", "SectionTitle");
		UserTaskParent.Visible = True;
		DisplayedUserTasksAndSections.Insert(SectionTitle);
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateToDoList(ToDoList)
	
	SectionsWithImportantUserTasks = New Structure;
	SavedViewSettings = ToDoListInternal.SavedViewSettings();
	If SavedViewSettings = Undefined Then
		SectionsVisibleSet = New Map;
		UserTasksVisibleSet      = New Map;
	Else
		SavedViewSettings.Property("SectionsVisibility", SectionsVisibleSet);
		SavedViewSettings.Property("UserTasksVisible", UserTasksVisibleSet);
	EndIf;
	
	CollapsedSections = CollapsedSections();
	
	ToDoList.Sort("IsSection Desc, SectionPresentation Asc, Important Desc");
	
	PutToTempStorage(ToDoList, UserTasksToStorage);
	
	// If the user does not adjust the position of sections in the to-do list, they are sorted in the 
	// order determined in procedure OnDetermineCommandInterfaceSectionsOrder.
	If SavedViewSettings = Undefined Then
		ToDoListInternal.SetInitialSectionsOrder(ToDoList);
	EndIf;
	
	CurrentGroup = "";
	CurrentCommonGroup = "";
	For Each UserTask In ToDoList Do
		
		If UserTask.IsSection Then
			
			// Create a common section group.
			CommonGroupName = "CommonGroup" + UserTask.OwnerID;
			If CurrentCommonGroup <> CommonGroupName Then
				
				SectionCollapsed = CollapsedSections[UserTask.OwnerID];
				If SectionCollapsed = Undefined Then
					If SavedViewSettings = Undefined
						AND CurrentCommonGroup <> "" Then
						// Cannot collapse the first group.
						CollapsedSections.Insert(UserTask.OwnerID, True);
						SectionCollapsed = True;
					Else
						CollapsedSections.Insert(UserTask.OwnerID, False);
					EndIf;
					
				EndIf;
				
				SectionVisibleEnabled = SectionsVisibleSet[UserTask.OwnerID];
				If SectionVisibleEnabled = Undefined Then
					SectionVisibleEnabled = True;
				EndIf;
				
				// Create a common group containing all items for displaying the section and to-dos included in it.
				CommonGroup = Folder(CommonGroupName,, "CommonGroup");
				CommonGroup.Visible = False;
				// Create a section title group.
				TitleGroupName = "SectionTitle" + UserTask.OwnerID;
				TitleGroup    = Folder(TitleGroupName, CommonGroup, "SectionTitle");
				// Create a section title.
				CreateCaption(UserTask, TitleGroup, SectionCollapsed);
				
				CurrentCommonGroup = CommonGroupName;
			EndIf;
			
			// Create a to-do group.
			NameOfGroup = "Group" + UserTask.OwnerID;
			If CurrentGroup <> NameOfGroup Then
				CurrentGroup = NameOfGroup;
				Folder        = Folder(NameOfGroup, CommonGroup);
				If TaxiInterface Then
					Folder.Representation = UsualGroupRepresentation.StrongSeparation;
				EndIf;
				
				If SectionCollapsed = True Then
					Folder.Visible = False;
				EndIf;
			EndIf;
			
			UserTaskVisibleEnabled = UserTasksVisibleSet[UserTask.ID];
			If UserTaskVisibleEnabled = Undefined Then
				UserTaskVisibleEnabled = True;
			EndIf;
			
			If SectionVisibleEnabled AND UserTaskVisibleEnabled AND UserTask.HasUserTasks Then
				DisplayedUserTasksAndSections.Insert(TitleGroupName);
				CommonGroup.Visible = True;
			EndIf;
			
			NewUserTask(UserTask, Folder, UserTaskVisibleEnabled);
			
			// Enable an indicator showing whether there are important to-dos.
			If UserTask.HasUserTasks
				AND UserTask.Important
				AND UserTaskVisibleEnabled Then
				
				If UserTask.OwnerID <> "" Then
					SectionsWithImportantUserTasks.Insert(UserTask.OwnerID, CollapsedSections[UserTask.OwnerID]);
				EndIf;
				
			EndIf;
			
		Else
			NewChildUserTask(UserTask);
		EndIf;
		
		FillUserTaskParameters(UserTask);
		
	EndDo;
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure OrderToDoList()
	
	SavedViewSettings = ToDoListInternal.SavedViewSettings();
	If SavedViewSettings = Undefined Then
		Return;
	EndIf;
	
	SavedUserTaskTree = SavedViewSettings.UserTasksTree;
	IsFirstSection = True;
	For Each RowSection In SavedUserTaskTree.Rows Do
		If Not IsFirstSection Then
			MoveSection(RowSection);
		EndIf;
		IsFirstSection = False;
		IsFirstUserTask   = True;
		For Each RowUserTask In RowSection.Rows Do
			If Not IsFirstUserTask Then
				MoveUserTask(RowUserTask);
			EndIf;
			IsFirstUserTask = False;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Background update

&AtServer
Function GenerateToDoListInBackground()
	
	If ExclusiveMode() Then
		Return Undefined;
	EndIf;
	
	If TimeConsumingOperation <> Undefined Then
		TimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
	EndIf;
	
	If UserTasksToStorage = "" Then
		UserTasksToStorage = PutToTempStorage(Undefined, UUID);
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitForCompletion = 0; // run immediately
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Обновление списка текущих дел'; en = 'Update current to-dos'; pl = 'Aktualizacja bieżących zadań';es_ES = 'Actualizar las tareas pendientes actuales';es_CO = 'Actualizar las tareas pendientes actuales';tr = 'Mevcut işleri güncelle';it = 'Aggiornare impegni correnti';de = 'Aktuelle Aufgaben aktualisieren'");
	ExecutionParameters.ResultAddress = UserTasksToStorage;
	ExecutionParameters.RunInBackground = True; // Always in the background (job order in file mode).
	
	Result = TimeConsumingOperations.ExecuteInBackground("ToDoListInternal.GenerateToDoListForUser",
		New Structure, ExecutionParameters);
		
	Return Result;
	
EndFunction

&AtServer
Procedure ImportToDoList(ToDoListAddress)
	
	ToDoList = GetFromTempStorage(ToDoListAddress);
	DisplayedUserTasksAndSections = New Structure;
	If OnlyUpdateUserTasks Then
		FillCollapsedGroups();
		RefreshToDoList(ToDoList);
	Else
		OnlyUpdateUserTasks = True;
		GenerateToDoList(ToDoList);
	EndIf;
	
	// If there are collapsed section with important to-dos, they are highlighted.
	SetPictureOfSectionsWithImportantToDos();
	
	If DisplayedUserTasksAndSections.Count() = 0 Then
		Items.NoUserTasksPage.Visible = True;
	Else
		Items.NoUserTasksPage.Visible = False;
		// If to-dos are shown from one section only, its title is hidden.
		If DisplayedUserTasksAndSections.Count() = 1 Then
			DisplaySection = False;
		Else
			DisplaySection = True;
		EndIf;
		For Each SectionTitleItem In DisplayedUserTasksAndSections Do
			SectionTitle = SectionTitleItem.Key;
			Items[SectionTitle].Visible = DisplaySection;
			
			If Not DisplaySection Then
				UserTaskGroupName = StrReplace(SectionTitle, "SectionTitle", "Group");
				Items[UserTaskGroupName].Visible = True;
			EndIf;
		EndDo;
	EndIf;
	
	OrderToDoList();
	
EndProcedure

&AtClient
Procedure GenerateToDoListInBackgroundCompletion(Result, AdditionalParameters) Export
	
	TimeConsumingOperation = Undefined;
	
	Items.UserTasksPage.Visible = True;
	Items.TimeConsumingOperationPage.Visible = False;
	Items.FormRefresh.Enabled = True;

	If Result = Undefined Then
		Items.FormCustomize.Enabled = OnlyUpdateUserTasks;
		Return;
	ElsIf Result.Status = "Error" Then
		Items.FormCustomize.Enabled = OnlyUpdateUserTasks;
		Raise Result.BriefErrorPresentation;
	ElsIf Result.Status = "Completed" Then
		ImportToDoList(Result.ResultAddress);
		Items.FormCustomize.Enabled = True;
		If AutoUpdateSettings.Property("AutoRefreshEnabled")
			AND AutoUpdateSettings.AutoRefreshEnabled Then
			UpdatePeriod = AutoUpdateSettings.AutoRefreshPeriod * 60;
			AttachIdleHandler("UpdateCurrentToDosAutomatically", UpdatePeriod);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

&AtClient
Procedure StartToDoListUpdate(AutoUpdate = False, UpdateSilently = False)
	
	// If update is initiated manually, the handler of automatic to-do update is disabled.
	// It will be enabled again once the manual update is finished.
	If Not AutoUpdate Then
		DetachIdleHandler("UpdateCurrentToDosAutomatically");
	EndIf;
	
	TimeConsumingOperation = GenerateToDoListInBackground();
	If TimeConsumingOperation = Undefined Then
		Return;
	EndIf;

	If Not UpdateSilently Then
		Items.UserTasksPage.Visible = False;
		Items.TimeConsumingOperationPage.Visible = True;
		Items.FormCustomize.Enabled = False;
		Items.FormRefresh.Enabled  = False;
		Items.NoUserTasksPage.Visible = False;
	EndIf;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.Interval = 2; // Faster than a standard interval as it is shown on the home page.
	CompletionNotification = New NotifyDescription("GenerateToDoListInBackgroundCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

&AtServer
Function Folder(NameOfGroup, Parent = Undefined, GroupType = "")
	
	If Parent = Undefined Then
		Parent = Items.UserTasksPage;
	EndIf;
	
	Folder = Items.Add(NameOfGroup, Type("FormGroup"), Parent);
	Folder.Type = FormGroupType.UsualGroup;
	Folder.Representation = UsualGroupRepresentation.None;
	
	If GroupType = "SectionTitle" Then
		Folder.Group = ChildFormItemsGroup.AlwaysHorizontal;
	Else
		Folder.Group = ChildFormItemsGroup.Vertical;
	EndIf;
	
	Folder.ShowTitle = False;
	
	Return Folder;
	
EndFunction

&AtServer
Procedure NewUserTask(UserTask, Folder, UserTaskVisibleEnabled)
	
	UserTaskTitle = UserTask.Presentation + ?(UserTask.Count <> 0," (" + UserTask.Count + ")", "");
	
	Item = Items.Add(UserTask.ID, Type("FormDecoration"), Folder);
	Item.Type = FormDecorationType.Label;
	Item.HorizontalAlign = ItemHorizontalLocation.Left;
	Item.Title = UserTaskTitle;
	Item.Visible = (UserTaskVisibleEnabled AND UserTask.HasUserTasks);
	Item.AutoMaxWidth = False;
	Item.Hyperlink = ValueIsFilled(UserTask.Form);
	Item.SetAction("Click", "Attachable_ProcessHyperlinkClick");
	
	If UserTask.Important Then
		Item.TextColor = StyleColors.OverdueDataColor;
	EndIf;
	
	If ValueIsFilled(UserTask.ToolTip) Then
		Tooltip                    = New FormattedString(UserTask.ToolTip);
		Item.ToolTip            = Tooltip;
		Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateCaption(UserTask, Folder, SectionCollapsed)
	
	// Create a section collapsing/expanding picture.
	Item = Items.Add("Picture" + UserTask.OwnerID, Type("FormDecoration"), Folder);
	Item.Type = FormDecorationType.Picture;
	Item.Hyperlink = True;
	
	If SectionCollapsed = True Then
		If UserTask.HasUserTasks AND UserTask.Important Then
			Item.Picture = PictureLib.RedRightArrow;
		Else
			Item.Picture = PictureLib.RightArrow;
		EndIf;
	Else
		Item.Picture = PictureLib.DownArrow;
	EndIf;
	
	Item.PictureSize = PictureSize.AutoSize;
	Item.Width      = 2;
	Item.Height      = 1;
	Item.SetAction("Click", "Attachable_ProcessPictureClick");
	Item.ToolTip = NStr("ru = 'Развернуть/свернуть раздел'; en = 'Expand/collapse section'; pl = 'Rozwiń/Zwiń sekcję';es_ES = 'Expandir/plegar la sección';es_CO = 'Expandir/plegar la sección';tr = 'Bölümü genişlet/daralt';it = 'Espandi la sezione / compressione';de = 'Bereich erweitern / reduzieren'");
	
	// Create a section title.
	Item = Items.Add("Title" + UserTask.OwnerID, Type("FormDecoration"), Folder);
	Item.Type = FormDecorationType.Label;
	Item.HorizontalAlign = ItemHorizontalLocation.Left;
	Item.Title  = UserTask.SectionPresentation;
	If TaxiInterface Then
		Item.Font = New Font(WindowsFonts.DefaultGUIFont,, 12);
	Else
		Item.Font = New Font(,, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure NewChildUserTask(UserTask)
	
	If Not UserTask.HasUserTasks Then
		Return;
	EndIf;
	
	ItemUserTaskOwner = Items.Find(UserTask.OwnerID);
	If ItemUserTaskOwner = Undefined Then
		Return;
	EndIf;
	ItemUserTaskOwner.ToolTipRepresentation           = ToolTipRepresentation.ShowBottom;
	ItemUserTaskOwner.ExtendedToolTip.Font     = New Font(, 8);
	ItemUserTaskOwner.ExtendedToolTip.HorizontalStretch = True;
	
	SubordinateUserTaskTitle = SubordinateUserTaskTitle(ItemUserTaskOwner.ExtendedToolTip.Title, UserTask);
	
	ItemUserTaskOwner.ExtendedToolTip.Title = SubordinateUserTaskTitle;
	ItemUserTaskOwner.ExtendedToolTip.SetAction("URLProcessing", "Attachable_URLClickProcessing");
	ItemUserTaskOwner.ExtendedToolTip.AutoMaxWidth = False;
	
	// Enable an indicator showing whether there are important to-dos.
	If UserTask.HasUserTasks
		AND UserTask.Important
		AND ItemUserTaskOwner.Visible Then
		
		SectionID = StrReplace(ItemUserTaskOwner.Parent.Name, "Group", "");
		SectionsWithImportantUserTasks.Insert(SectionID, Not ItemUserTaskOwner.Parent.Visible);
	EndIf;
	
EndProcedure

&AtServer
Function SubordinateUserTaskTitle(CurrentTitle, UserTask)
	
	CurrentEmptyTitle = Not ValueIsFilled(CurrentTitle);
	UserTaskTitle = UserTask.Presentation + ?(UserTask.Count <> 0," (" + UserTask.Count + ")", "");
	RowUserTaskTitle    = UserTaskTitle;
	If UserTask.Important Then
		UserTaskColor        = StyleColors.OverdueDataColor;
	Else
		UserTaskColor        = StyleColors.ToDoListTitleColor;
	EndIf;
	
	FormattedStringWrap = New FormattedString(Chars.LF);
	FormattedStringIndent  = New FormattedString(Chars.NBSp+Chars.NBSp+Chars.NBSp);
	
	If UserTask.Important Then
		If ValueIsFilled(UserTask.Form) Then
			UserTaskTitleFormattedString = New FormattedString(
			                                           RowUserTaskTitle,,
			                                           UserTaskColor,,
			                                           UserTask.ID);
		Else
			UserTaskTitleFormattedString = New FormattedString(
			                                           RowUserTaskTitle,,
			                                           UserTaskColor);
		EndIf;
	Else
		If ValueIsFilled(UserTask.Form) Then
			UserTaskTitleFormattedString = New FormattedString(
			                                           RowUserTaskTitle,,,,
			                                           UserTask.ID);
		Else
			UserTaskTitleFormattedString = New FormattedString(RowUserTaskTitle,,UserTaskColor);
		EndIf;
	EndIf;
	
	If CurrentEmptyTitle Then
		Return New FormattedString(FormattedStringIndent, UserTaskTitleFormattedString);
	Else
		Return New FormattedString(CurrentTitle, FormattedStringWrap, FormattedStringIndent, UserTaskTitleFormattedString);
	EndIf;
	
EndFunction

&AtServer
Procedure FillUserTaskParameters(UserTask)
	
	FillPropertyValues(UserTasksParameters.Add(), UserTask);
	
EndProcedure

&AtServer
Procedure LoadAutoRefreshSettings()
	
	AutoUpdateSettings = Common.CommonSettingsStorageLoad("ToDoList", "AutoUpdateSettings");
	
	If AutoUpdateSettings = Undefined Then
		AutoUpdateSettings = New Structure;
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyToDoListPanel(ApplySettings, AdditionalParameters) Export
	If ApplySettings = True Then
		StartToDoListUpdate();
	EndIf;
EndProcedure

&AtServer
Procedure MoveSection(RowSection)
	
	ItemName = "CommonGroup" + RowSection.ID;
	ItemToMove = Items.Find(ItemName);
	If ItemToMove = Undefined Then
		Return;
	EndIf;
	Items.Move(ItemToMove, ItemToMove.Parent);
	
EndProcedure

&AtServer
Procedure MoveUserTask(RowUserTask)
	
	ItemToMove = Items.Find(RowUserTask.ID);
	If ItemToMove = Undefined Then
		Return;
	EndIf;
	Items.Move(ItemToMove, ItemToMove.Parent);
	
EndProcedure

&AtServer
Procedure SaveCollapsedSections(CollapsedSections)
	
	ViewSettings = Common.CommonSettingsStorageLoad("ToDoList", "ViewSettings");
	
	If TypeOf(ViewSettings) <> Type("Structure") Then
		ViewSettings = New Structure;
	EndIf;
	
	ViewSettings.Insert("CollapsedSections", CollapsedSections);
	Common.CommonSettingsStorageSave("ToDoList", "ViewSettings", ViewSettings);
	
EndProcedure

&AtServer
Function CollapsedSections()
	
	ViewSettings = Common.CommonSettingsStorageLoad("ToDoList", "ViewSettings");
	If ViewSettings <> Undefined AND ViewSettings.Property("CollapsedSections") Then
		CollapsedSections = ViewSettings.CollapsedSections;
	Else
		CollapsedSections = New Map;
	EndIf;
	
	Return CollapsedSections;
	
EndFunction

&AtServer
Procedure FillCollapsedGroups()
	
	ViewSettings = Common.CommonSettingsStorageLoad("ToDoList", "ViewSettings");
	If ViewSettings = Undefined Or Not ViewSettings.Property("CollapsedSections") Then
		Return;
	EndIf;
	
	CollapsedSections = New Map;
	For Each MapRow In ViewSettings.CollapsedSections Do
		
		FormItem = Items.Find("Picture" + MapRow.Key);
		If FormItem = Undefined Then
			Continue;
		EndIf;
		
		If FormItem.Picture = PictureLib.RightArrow
			Or FormItem.Picture = PictureLib.RedRightArrow Then
			CollapsedSections.Insert(MapRow.Key, True);
		Else
			CollapsedSections.Insert(MapRow.Key, False);
		EndIf;
		
	EndDo;
	
	If CollapsedSections.Count() = 0 Then
		Return;
	EndIf;
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure SwitchPicture(ItemName)
	
	SectionGroupName = StrReplace(ItemName, "Picture", "");
	Item = Items[ItemName];
	
	Collapsed = False;
	If Item.Picture = PictureLib.DownArrow Then
		If SectionsWithImportantUserTasks.Property(SectionGroupName) Then
			Item.Picture = PictureLib.RedRightArrow;
		Else
			Item.Picture = PictureLib.RightArrow;
		EndIf;
		Items["Group" + SectionGroupName].Visible = False;
		Collapsed = True;
	Else
		Item.Picture = PictureLib.DownArrow;
		Items["Group" + SectionGroupName].Visible = True;
	EndIf;
	
	CollapsedSections = CollapsedSections();
	CollapsedSections.Insert(SectionGroupName, Collapsed);
	
	SaveCollapsedSections(CollapsedSections);
	
EndProcedure

&AtServer
Procedure SetPictureOfSectionsWithImportantToDos()
	
	For Each SectionWithImportantToDos In SectionsWithImportantUserTasks Do
		If SectionWithImportantToDos.Value <> True Then
			Continue; // Section not collapsed
		EndIf;
		PictureName = "Picture" + SectionWithImportantToDos.Key;
		ItemPicture = Items[PictureName];
		ItemPicture.Picture = PictureLib.RedRightArrow;
	EndDo;
	
EndProcedure

&AtClient
Procedure ProcessHyperlinkClickCompletion(Result, AdditionalParameters) Export
	StartToDoListUpdate(, True);
EndProcedure

#EndRegion
