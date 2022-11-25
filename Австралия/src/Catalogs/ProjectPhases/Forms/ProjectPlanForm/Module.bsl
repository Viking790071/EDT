
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ViewMode = "Planning";
	EditOption = "InList";
	
	Project = Parameters.Project;
	
	ThisObject.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Plan of project ""%1""'; ru = 'План проекта ""%1""';pl = 'Plan projektu ""%1""';es_ES = 'Plan del proyecto ""%1""';es_CO = 'Plan del proyecto ""%1""';tr = '""%1"" projesinin planı';it = 'Piano del progetto ""%1""';de = 'Plan des Projekts ""%1""'"),
		String(Project));
	
	If Not GetFunctionalOption("UseBusinessProcessesAndTasks") Then
		Items.Tasks.Visible = False;
	EndIf;
	
	ProjectAttributes = Common.ObjectAttributesValues(Project,
		"Ref, WorkSchedule, UseWorkSchedule, StartDate, 
		|EndDate, DurationUnit, Status, Company, CalculateDeadlinesAutomatically");
	
	ProjectAttributes.Insert("IsAvailableForModification", AccessRight("Update", Metadata.Catalogs.ProjectPhases));
	ProjectAttributes.Insert("ProjectCompeted", ProjectAttributes.Status = Enums.ProjectStatuses.Completed);
	
	If Parameters.Property("StateOfProjectPhases") Then 
		TransmittedStateOfProjectPhases = Parameters.StateOfProjectPhases;
	EndIf;
	
	StateOfProjectPhases = "All";
	If ValueIsFilled(TransmittedStateOfProjectPhases) Then 
		StateOfProjectPhases = TransmittedStateOfProjectPhases;
	EndIf;
	
	FillInPhaseTree();
	
	If Not ProjectAttributes.IsAvailableForModification Or ProjectAttributes.ProjectCompeted Then
		Items.PhaseTree.ChangeRowSet = False;
		Items.PhaseTree.ChangeRowOrder = False;
		Items.PhaseTreeGroupChangingOrderOfPhases.Enabled = False;
		Items.PhaseTreeGroupAdd.Enabled = False;
		Items.PhaseTreeConnectPhases.Enabled = False;
		Items.PhaseTreeContextMenuConnectPhases.Enabled = False;
		Items.PhaseTreeContextMenuGroupAdd.Enabled = False;
		Items.PhaseTreeContextMenuGroupChangingOrderOfPhases.Enabled = False;
	Else
		Items.PhaseTree.ChangeRowSet = True;
		Items.PhaseTree.ChangeRowOrder = True;
		Items.PhaseTreeGroupChangingOrderOfPhases.Enabled = True;
		Items.PhaseTreeGroupAdd.Enabled = True;
		Items.PhaseTreeConnectPhases.Enabled = True;
		Items.PhaseTreeContextMenuConnectPhases.Enabled = True;
		Items.PhaseTreeContextMenuGroupAdd.Enabled = True;
		Items.PhaseTreeContextMenuGroupChangingOrderOfPhases.Enabled = True;
	EndIf;
	
	SetVisibility(ViewMode);
	
	SetAvailabilityOfPhaseTreeFields(EditOption);
	
	Items.LoadFromTemplate.Enabled = (ProjectAttributes.Status = Enums.ProjectStatuses.Open);
	
	ShowProcessesTasks = False;
	Items.GroupTasks.Visible = ShowProcessesTasks;
	Items.PhaseTreeShowProcessesTasks.Check = ShowProcessesTasks;
	
	ShowMarkedToDelete = False;
	Items.PhaseTreeShowMarkedToDelete.Check = ShowMarkedToDelete;
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	
	DateFormatForColumns = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	Items.MainTasksDueDate.Format = DateFormatForColumns;
	
	If ProjectAttributes.ProjectCompeted Then
		Items.EditingIsProhibitedTitle.Visible = True;
		Items.EditingIsProhibitedTitle.Title = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
	ElsIf Not ProjectAttributes.IsAvailableForModification Then
		Items.EditingIsProhibitedTitle.Visible = True;
		Items.EditingIsProhibitedTitle.Title = ProjectManagementClientServer.NoRightsEditMessageText();
	EndIf;
	
	FormSettings = Common.SystemSettingsStorageLoad(FormName + "/CurrentData", "");
	If FormSettings = Undefined Or FormSettings.Get("ByExecutor") = Undefined Then
		ByExecutor = Catalogs.Users.EmptyRef();
	EndIf;
	
	SetConditionalAppearanceOnCreate();
	
	// StandardSubsystems.AttachableCommands
	PlacementParameters = AttachableCommands.PlacementParameters();
	PlacementParameters.CommandBar = Items.GroupPrint;
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	For Each Row In PhaseTree.GetItems() Do
		Items.PhaseTree.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ProjectPhaseChanged" And Parameter.Project = Project Then
		
		Index = -1;
		ProjectManagementClientServer.FindPhaseInTreeByRef(PhaseTree.GetItems(), Parameter.ProjectPhase, Index);
		
		FoundRow = PhaseTree.FindByID(Index);
		If Parameter.Parent <> FoundRow.ParentPhase Then
			UpdatePhaseTree();
		Else
			UpdateModifiedRowsOfPhases(Parameter.ModifiedPhasesArray);
		EndIf;
		
		SetEnableByStatus();
		
	EndIf;
	
	If EventName = "ProjectPhaseCreated" And Parameter.Project = Project Then
		
		If ValueIsFilled(Parameter.Parent) Then
			Index = -1;
			ProjectManagementClientServer.FindPhaseInTreeByRef(PhaseTree.GetItems(), Parameter.Parent, Index);
			
			NewRow = PhaseTree.FindByID(Index).GetItems().Add();
		Else
			NewRow = PhaseTree.GetItems().Add();
		EndIf;
		
		NewRow.Ref = Parameter.ProjectPhase;
		Items.PhaseTree.CurrentRow = NewRow.GetID();
		
		ModifiedPhasesArray = New Array;
		ModifiedPhasesArray.Add(Parameter.ProjectPhase);
		
		For Each Row In Parameter.ModifiedPhasesArray Do
			ModifiedPhasesArray.Add(Row);
		EndDo;
		
		If ValueIsFilled(Parameter.Parent) Then
			ModifiedPhasesArray.Add(Parameter.Parent);
		EndIf;
		
		UpdateModifiedRowsOfPhases(ModifiedPhasesArray);
		
		SetEnableByStatus();
		
	EndIf;
	
	If EventName = "BusinessProcessStarted" And Parameter.Project = Project Then
		
		If ValueIsFilled(Parameter.ProjectPhase) Then
			
			Index = -1;
			ProjectManagementClientServer.FindPhaseInTreeByRef(PhaseTree.GetItems(), Parameter.ProjectPhase, Index);
			
			FoundRow = PhaseTree.FindByID(Index);
			FoundRow.Tasks = True;
			
			UpdateSmallCard();
			
		EndIf;
		
	EndIf;
	
	If EventName = "Write_PerformerTask" Then
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData <> Undefined Then
			
			TaskProject = Undefined;
			TaskProjectPhase = Undefined;
			
			If TypeOf(Parameter) = Type("Structure")
				And Parameter.Property("Project", TaskProject)
				And Parameter.Property("ProjectPhase", TaskProjectPhase) Then
				
				If ValueIsFilled(TaskProject)
					And ValueIsFilled(TaskProjectPhase)
					And TaskProject = Project
					And TaskProjectPhase = CurrentData.Ref Then
					
					UpdateSmallCard();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If EventName = "Change_Project" And Parameter.Project = Project Then
		
		UpdatePhaseTree();
		
		For Each Row In PhaseTree.GetItems() Do
			Items.PhaseTree.Expand(Row.GetID(), True);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	If ValueIsFilled(TransmittedStateOfProjectPhases) Then
		Settings.Insert("StateOfProjectPhases", SavedStateOfProjectPhases);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Not ValueIsFilled(TransmittedStateOfProjectPhases) Then
		StateOfProjectPhases = Settings["StateOfProjectPhases"];
		FillInPhaseTree();
	Else
		SavedStateOfProjectPhases = Settings["StateOfProjectPhases"];
		StateOfProjectPhases = TransmittedStateOfProjectPhases;
	EndIf;
	
	SetVisibility(Settings["ViewMode"]);
	
	SetAvailabilityOfPhaseTreeFields(Settings["EditOption"]);
	
	ShowProcessesTasks = Settings["ShowProcessesTasks"];
	Items.GroupTasks.Visible = ShowProcessesTasks;
	Items.PhaseTreeShowProcessesTasks.Check = ShowProcessesTasks;
	
	ShowMarkedToDelete = Settings["ShowMarkedToDelete"];
	Items.PhaseTreeShowMarkedToDelete.Check = ShowMarkedToDelete;
	
	ShowHideClearButton(Items.ByExecutor, ByExecutor);
	ShowHideClearButton(Items.StateOfProjectPhases, StateOfProjectPhases);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ViewModeOnChange(Item)
	
	SetVisibility(ViewMode);
	
EndProcedure

&AtClient
Procedure StateOfProjectPhasesOnChange(Item)
	
	If Not ValueIsFilled(StateOfProjectPhases) Then 
		StateOfProjectPhases = "All";
	EndIf;
	
	UpdatePhaseTree();
	
	If StateOfProjectPhases = "All" Then
		For Each Row In PhaseTree.GetItems() Do
			Items.PhaseTree.Expand(Row.GetID(), True);
		EndDo;
	EndIf;
	
	ShowHideClearButton(Items.StateOfProjectPhases, StateOfProjectPhases);
	
EndProcedure

&AtClient
Procedure ByExecutorOnChange(Item)
	
	UpdatePhaseTree();
	
	ShowHideClearButton(Items.ByExecutor, ByExecutor);
	
EndProcedure

&AtClient
Procedure ByExecutorAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure ByExecutorTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPhaseTree

&AtClient
Procedure PhaseTreeOnActivateRow(Item)
	
	If Items.GroupPages.CurrentPage <> Items.GroupProjectPhases Then 
		Return;
	EndIf;
	
	If Item.CurrentData = Undefined Then
		
		CurrentProjectPhase = PredefinedValue("Catalog.ProjectPhases.EmptyRef");
		
		Items.PhaseTreeUp.Enabled = False;
		Items.PhaseTreeDown.Enabled= False;
		Items.PhaseTreeLevelUp.Enabled = False;
		Items.PhaseTreeLevelDown.Enabled = False;
		
		Items.PhaseTreeContextMenuUp.Enabled = False;
		Items.PhaseTreeContextMenuDown.Enabled = False;
		Items.PhaseTreeContextMenuLevelUp.Enabled = False;
		Items.PhaseTreeContextMenuLevelDown.Enabled = False;
		
		Return;
		
	EndIf;
	
	If NumberOfSelectedPhases <> Items.PhaseTree.SelectedRows.Count() Or CurrentProjectPhase <> Item.CurrentData.Ref Then
		NumberOfSelectedPhases = Items.PhaseTree.SelectedRows.Count();
		CurrentProjectPhase = Item.CurrentData.Ref;
		SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items);
	EndIf;
	
	If EditOption = "InList" Then
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		Items.StartDate.ReadOnly = CurrentData.SummaryPhase;
		Items.EndDate.ReadOnly = CurrentData.SummaryPhase;
		Items.DurationStr.ReadOnly = CurrentData.SummaryPhase;
		Items.Status.ReadOnly = CurrentData.SummaryPhase;
		
		SetEnableActualAttributes(CurrentData);
		
	EndIf;
	
	SetEnableByStatus();
	
	If ShowProcessesTasks Then 
		AttachIdleHandler("UpdateSmallCard", 0.2, True);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure PhaseTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	If Field = Items.Tasks Then
		Filter = New Structure("ProjectPhase", CurrentData.Ref);
		OpenForm("BusinessProcess.ProjectJob.Form.TasksByProject", New Structure("Filter", Filter), ThisObject);
		Return;
	EndIf;
	
	If EditOption = "InDialog"
		Or Not ProjectAttributes.IsAvailableForModification
		Or ProjectAttributes.ProjectCompeted Then
		
		If Field = Items.PreviousPhase And ValueIsFilled(CurrentData.PreviousPhase) Then
			FormParameters = New Structure("Key", CurrentData.PreviousPhase);
			OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
			Return;
		EndIf;
		
		FormParameters = New Structure("Key", CurrentData.Ref);
		OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
		Return;
		
	EndIf;
	
	StandardProcessing = True;
	
EndProcedure

&AtClient
Procedure PhaseTreeBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
	If Not ProjectAttributes.IsAvailableForModification Then 
		MessageText = ProjectManagementClientServer.NoRightsEditMessageText();
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If ProjectAttributes.ProjectCompeted Then 
		MessageText = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
		CommonClientServer.MessageToUser(MessageText);
		CancelEdit = True;
		Return;
	EndIf;
	
	If EditOption = "InList" Then 
		
		CurrentRow = Items.PhaseTree.CurrentRow;
		If CurrentRow = Undefined Then
			NewItem = PhaseTree.GetItems().Add();
		Else
			TreeItem = PhaseTree.FindByID(CurrentRow);
			ItemParent = TreeItem.GetParent();
			
			If ItemParent = Undefined Then
				NewItem = PhaseTree.GetItems().Add();
			Else
				NewItem = ItemParent.GetItems().Add();
			EndIf;
			
			If Clone Then
				
				NewItem.Clone = True;
				NewItem.ParentPhase = TreeItem.ParentPhase;
				NewItem.Description = TreeItem.Description;
				NewItem.Status = TreeItem.Status;
				NewItem.StartDate = TreeItem.StartDate;
				NewItem.EndDate = TreeItem.EndDate;
				NewItem.Duration = TreeItem.Duration;
				NewItem.DurationUnit = TreeItem.DurationUnit;
				NewItem.Executor = TreeItem.Executor;
				NewItem.PreviousPhase = TreeItem.PreviousPhase;
				
			EndIf;
		EndIf;
		
		Items.PhaseTree.CurrentRow = NewItem.GetID();
		Items.PhaseTree.ChangeRow();
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("Project", Project);
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData <> Undefined Then
			
			FormParameters.Insert("Parent", CurrentData.ParentPhase);
			
			If Clone Then
				FormParameters.Insert("CopyingValue", CurrentData.Ref);
			EndIf;
			
		EndIf;
		
		OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeBeforeRowChange(Item, Cancel)
	
	If EditOption = "InDialog" 
		Or Not ProjectAttributes.IsAvailableForModification
		Or ProjectAttributes.ProjectCompeted Then
		
		Cancel = True;
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", CurrentData.Ref);
		
		OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
		
	Else
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		LockRowForEdit(CurrentData.Ref, UUID);
		
		If Item.CurrentItem.Name = "PhaseName" Then
			CurrentData.PhaseName = CurrentData.Description;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeOnStartEdit(Item, NewRow, Clone)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Owner) Then
		
		CurrentData.Owner = Project;
		
		If Not CurrentData.Clone Then
			
			ItemParent = CurrentData.GetParent();
			
			If ItemParent = Undefined Then
				TreeItems = PhaseTree.GetItems();
			Else
				TreeItems = ItemParent.GetItems();
			EndIf;
			
			ItemsCount = TreeItems.Count();
			
			SetPrevious = False;
			If ItemsCount >= 3 Then
				
				LastPhase = TreeItems[ItemsCount - 2];
				PenultimatePhase = TreeItems[ItemsCount - 3];
				
				If LastPhase.PreviousPhase = PenultimatePhase.Ref Then
					SetPrevious = True;
				EndIf;
				
			EndIf;
			
			If SetPrevious Then
				
				CurrentData.PreviousPhase = LastPhase.Ref;
				CurrentData.StartDate = LastPhase.EndDate;
				
			Else
				
				If ItemParent = Undefined Then
					
					CurrentData.StartDate = ProjectAttributes.StartDate;
					
				Else
					
					CurrentData.StartDate = ItemParent.StartDate;
					
				EndIf;
				
			EndIf;
			
			If ItemParent <> Undefined Then
				CurrentData.ParentPhase = ItemParent.Ref;
			EndIf;
			
			CurrentData.Duration = 1;
			CurrentData.Status = PredefinedValue("Enum.ProjectPhaseStatuses.Open");
			
			ProjectPhaseStructure = New Structure;
			ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
			ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
			
			CurrentData.EndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
				CurrentData.StartDate,
				CurrentData.Duration,
				CurrentData.DurationUnit);
			
		EndIf;
		
		DurationPresentation = GetDurationPresentation(CurrentData.DurationUnit);
		CurrentData.DurationStr = String(CurrentData.Duration) + " " + DurationPresentation;
		
		CurrentData.DurationUnit = ProjectAttributes.DurationUnit;
		CurrentData.ActualDurationUnit = ProjectAttributes.DurationUnit;
		
	EndIf;
	
	StartDateBeforeChanging = CurrentData.StartDate;
	EndDateBeforeChanging = CurrentData.EndDate;
	
EndProcedure

&AtClient
Procedure PhaseTreeBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CancelEdit Then
		
		CurrentRow = Items.PhaseTree.CurrentRow;
		TreeItem = PhaseTree.FindByID(CurrentRow);
		
		If Not ValueIsFilled(CurrentData.Ref) Then
			
			Cancel = True;
			
			ItemParent = TreeItem.GetParent();
			If ItemParent = Undefined Then 
				ItemIndex = PhaseTree.GetItems().IndexOf(TreeItem);
				PhaseTree.GetItems().Delete(ItemIndex);
			Else
				ItemIndex = ItemParent.GetItems().IndexOf(TreeItem);
				ItemParent.GetItems().Delete(ItemIndex);
			EndIf;
			
			Return;
			
		EndIf;
		
	Else
		
		If Not ValueIsFilled(CurrentData.Description) Then
			MessageText = NStr("en = 'Description is required.'; ru = 'Укажите наименование.';pl = 'Opis jest wymagany.';es_ES = 'Se requiere una descripción.';es_CO = 'Se requiere una descripción.';tr = 'Tanım gerekli.';it = 'Descrizione necessaria.';de = 'Beschreibung ist erforderlich.'");
			CommonClientServer.MessageToUser(MessageText, , , ,Cancel);
			Return;
		EndIf;
		
		If Not ValueIsFilled(CurrentData.StartDate) Then 
			MessageText = NStr("en = 'Start (plan) is required.'; ru = 'Требуется указать дату начала (план).';pl = 'Rozpoczęcie (planowane) jest wymagane.';es_ES = 'Se requiere indicar una fecha de inicio (plan).';es_CO = 'Se requiere indicar una fecha de inicio (plan).';tr = 'Başlangıç (planlanan) gerekli.';it = 'Avvio (secondo il piano) richiesto.';de = 'Start(Plan) ist erforderlich.'");
			CommonClientServer.MessageToUser(MessageText, , , ,Cancel);
			Return;
		EndIf;
		
		If Not ValueIsFilled(CurrentData.EndDate) Then 
			MessageText = NStr("en = 'End (plan) is required.'; ru = 'Требуется указать дату завершения (план).';pl = 'Zakończenie (planowane) jest wymagane.';es_ES = 'Se requiere indicar una fecha final (plan).';es_CO = 'Se requiere indicar una fecha final (plan).';tr = 'Bitiş (planlanan) gerekli.';it = 'Fine (programmata) richiesta.';de = 'End(Plan) ist erforderlich.'");
			CommonClientServer.MessageToUser(MessageText, , , ,Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CancelEdit Then
		
		UnlockRowForEdit(CurrentData.Ref, UUID);
		
		ModifiedPhasesArray = New Array;
		ModifiedPhasesArray.Add(CurrentData.Ref);
		UpdateModifiedRowsOfPhases(ModifiedPhasesArray);
		
		Return;
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("PeriodOnChangeHandlerEnd",
		ThisObject,
		New Structure("CurrentData", CurrentData));
	
	If Item.CurrentItem.Name = "StartDate"
		Or Item.CurrentItem.Name = "EndDate"
		Or Item.CurrentItem.Name = "DurationStr" Then
		
		If ProjectAttributes.CalculateDeadlinesAutomatically Then
			
			ChangedPhases = New Array;
			ChangedPhases.Add(CurrentData.Ref);
			
			NextPhases = GetNextPhasesOfPhases(ChangedPhases);
			
			If NextPhases.Count() > 0 Then
				
				MessageText = NStr("en = 'This phase has dependent phases. If you continue to change ""%1"" of this phase,
										|the dependent phase dates will be changed accordingly. Continue?'; 
										|ru = 'У этого этапа есть подчиненные этапы. Если вы продолжите изменять ""%1"" данного этапа,
										|даты подчиненного этапа будут изменены соответствующим образом. Продолжить?';
										|pl = 'Ten etap ma zależne etapy. W razie kontynuacji zmiany ""%1"" tego etapu,
										|daty etapu zależnego odpowiednio zostaną zmienione. Kontynuować?';
										|es_ES = 'Esta fase tiene fases dependientes. Si continúa cambiando ""%1"" de esta fase,
										|las fechas de las fases dependientes se modificarán en consecuencia. ¿Continuar?';
										|es_CO = 'Esta fase tiene fases dependientes. Si continúa cambiando ""%1"" de esta fase,
										|las fechas de las fases dependientes se modificarán en consecuencia. ¿Continuar?';
										|tr = 'Bu evrede bağlı evreler var. Bu evrede ""%1"" değiştirilirse
										|bağlı evre tarihleri de buna göre değiştirilecek. Devam edilsin mi?';
										|it = 'Questa fase ha fasi dipendenti. Continuando a modificare ""%1"" di questa fase,
										|le date delle fasi dipendenti saranno modificate di conseguenza. Continuare?';
										|de = 'Die Phase hat abgeleiteten Phasen. Wenn Sie mit den Änderungen zu ""%1"" fortfahren,
										| werden die abgeleiteten Phasendaten auch geändert. Weiter?'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
					Item.CurrentItem.Title);
				ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ExecuteNotifyProcessing(NotifyDescription, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure PeriodOnChangeHandlerEnd(Result, AdditionalParameters) Export
	
	CurrentData = AdditionalParameters.CurrentData;
	
	If Result = DialogReturnCode.Yes Then
		
		ModifiedPhasesArray = New Array;
		WriteProjectPhaseFromTreeRow(Items.PhaseTree.CurrentRow, ModifiedPhasesArray);
		
		If ModifiedPhasesArray.Count() > 1 Then
			
			UpdatedPhasesPresentations = ProjectManagement.GetPhasesPresentations(ModifiedPhasesArray);
			Explanation = "";
			
			For Each UpdatedPhaseItem In UpdatedPhasesPresentations Do
				
				If IsBlankString(Explanation) Then
					Explanation = "  " + UpdatedPhaseItem.Value;
				Else
					Explanation = Explanation + "," + "
						|  " + UpdatedPhaseItem.Value;
				EndIf;
				
			EndDo;
			
			ShowUserNotification(NStr("en = 'The phases have been changed:'; ru = 'Изменены этапы:';pl = 'Etapy zostały zmienione:';es_ES = 'Se han cambiado las fases:';es_CO = 'Se han cambiado las fases:';tr = 'Evreler değiştirildi:';it = 'Le fasi sono state modificate:';de = 'Die Phasen wurden geändert:'"),
				,
				Explanation,
				PictureLib.Information32,
				UserNotificationStatus.Important);
			
		EndIf;
		
	Else
		
		UnlockRowForEdit(CurrentData.Ref, UUID);
		
		ModifiedPhasesArray = New Array;
		ModifiedPhasesArray.Add(CurrentData.Ref);
		UpdateModifiedRowsOfPhases(ModifiedPhasesArray);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	If Not ProjectAttributes.IsAvailableForModification Then 
		MessageText = ProjectManagementClientServer.NoRightsEditMessageText();
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If ProjectAttributes.ProjectCompeted Then
		MessageText = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
		CommonClientServer.MessageToUser(MessageText);
		CancelEdit = True;
		Return;
	EndIf;
	
	SelectedRows = Item.SelectedRows;
	If SelectedRows = Undefined Or SelectedRows.Count() <= 0 Then
		Return;
	EndIf;
	
	Mode = QuestionDialogMode.YesNo;
	NotificationParameters = New Structure;
	NotificationParameters.Insert("SelectedRows", SelectedRows);
	
	If SelectedRows.Count() = 1 Then
		
		If Not Items.PhaseTree.CurrentData.DeletionMark Then
			
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Mark ""%1"" for deletion?'; ru = 'Пометить ""%1"" на удаление?';pl = 'Zaznaczyć ""%1"" do usunięcia?';es_ES = '¿Marcar ""%1"" para eliminar?';es_CO = '¿Marcar ""%1"" para eliminar?';tr = '""%1"" silinmek üzere işaretlensin mi?';it = 'Contrassegnare ""%1"" per l''eliminazione?';de = '""%1"" zum Löschen markieren?'"),
				String(Items.PhaseTree.CurrentData.Ref));
			
			NotificationParameters.Insert("DeletionMark", True);
			NotifyDescription = New NotifyDescription("PhaseTreeBeforeDeleteRowEnd", ThisObject, NotificationParameters);
			
			ShowQueryBox(NotifyDescription, QuestionText, Mode);
			
		Else
			
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Clear ""%1"" deletion mark?'; ru = 'Снять с ""%1"" пометку на удаление?';pl = 'Usunąć zaznaczenie do usunięcia ""%1""?';es_ES = '¿Desmarcar la marca de borrado ""%1""?';es_CO = '¿Desmarcar la marca de borrado ""%1""?';tr = '""%1"" öğesinin silme işareti silinsin mi?';it = 'Rimuovere il contrassegno di eliminazione da ""%1""?';de = 'Löschmarkierung ""%1"" entfernen?'"),
				String(Items.PhaseTree.CurrentData.Ref));
			
			NotificationParameters.Insert("DeletionMark", False);
			NotifyDescription = New NotifyDescription("PhaseTreeBeforeDeleteRowEnd", ThisObject, NotificationParameters);
			
			ShowQueryBox(NotifyDescription, QuestionText, Mode);
			
		EndIf;
		
	ElsIf SelectedRows.Count() > 1 Then
		
		DeletionMark = True;
		
		For Each Row In SelectedRows Do
			ProjectPhaseRow = PhaseTree.FindByID(Row);
			If ProjectPhaseRow.DeletionMark Then
				DeletionMark = False;
				Break;
			EndIf;
		EndDo;
		
		If DeletionMark Then
			
			NotificationParameters.Insert("DeletionMark", True);
			NotifyDescription = New NotifyDescription("PhaseTreeBeforeDeleteRowEnd", ThisObject, NotificationParameters);
			
			ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to mark selected elements for deletion?'; ru = 'Пометить выделенные элементы на удаление?';pl = 'Czy chcesz zaznaczyć wybrane elementy do usunięcia?';es_ES = '¿Marcar los elementos seleccionados para borrarlos?';es_CO = '¿Marcar los elementos seleccionados para borrarlos?';tr = 'Seçilen öğeler silinmek üzere işaretlensin mi?';it = 'Contrassegnare gli elementi selezionati per l''eliminazione?';de = 'Möchten Sie die ausgewählten Elemente zum Löschen markieren?'"), Mode);
			
		Else
			
			NotificationParameters.Insert("DeletionMark", False);
			NotifyDescription = New NotifyDescription("PhaseTreeBeforeDeleteRowEnd", ThisObject, NotificationParameters);
			
			ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to remove the deletion mark for selected elements?'; ru = 'Снять пометку на удаление c выделенных элементов?';pl = 'Czy chcesz usunąć zaznaczenie do usunięcia dla wybranych elementów?';es_ES = '¿Borrar la marca de borrado de los elementos seleccionados?';es_CO = '¿Borrar la marca de borrado de los elementos seleccionados?';tr = 'Seçilen öğelerin silme işareti kaldırılsın mı?';it = 'Rimuovere il contrassegno di eliminazione dagli elementi selezionati?';de = 'Möchten Sie die Löschmarkierungen für die ausgewählte Elemente entfernen?'"), Mode);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeBeforeDeleteRowEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	SelectedRows = AdditionalParameters.SelectedRows;
	DeletionMark = AdditionalParameters.DeletionMark;
	
	ExpandedPhasesList.Clear();
	
	ProjectManagementClient.GetExpandedPhasesArray(Items.PhaseTree, PhaseTree.GetItems(), ExpandedPhasesList);
	
	TempCurrentProjectPhase = CurrentProjectPhase;
	
	SetDeletionMarkProjectPhases(SelectedRows, DeletionMark);
	ProjectManagementClient.SetTreeItemsExpanded(Items.PhaseTree, PhaseTree, ExpandedPhasesList);
	
	If ShowMarkedToDelete Then
		ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, TempCurrentProjectPhase);
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	If Row <> Undefined Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure PhaseTreeDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If Not ProjectAttributes.IsAvailableForModification Then
		MessageText = ProjectManagementClientServer.NoRightsEditMessageText();
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If ProjectAttributes.ProjectCompeted Then
		MessageText = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
		CommonClientServer.MessageToUser(MessageText);
		CancelEdit = True;
		Return;
	EndIf;
	
	SourceRow = DragParameters.Value[0];
	SourceTreeRow = PhaseTree.FindByID(SourceRow);
	If SourceTreeRow = Undefined Then 
		Return;
	EndIf;
	
	SourceRef = SourceTreeRow.Ref;
	
	If Row <> Undefined Then
		
		ReceiverRow = Row;
		ReceiverTreeRow = PhaseTree.FindByID(ReceiverRow);
		ReceiverRef = ReceiverTreeRow.Ref;
		
		If Not SourceTreeRow.DeletionMark And ReceiverTreeRow.DeletionMark Then 
			Return;
		EndIf;
		
	Else
		ReceiverRef = Undefined;
	EndIf;
	
	If SourceRef = ReceiverRef Then
		Return;
	EndIf;
	
	ExpandedPhasesList.Clear();
	
	ProjectManagementClient.GetExpandedPhasesArray(Items.PhaseTree, PhaseTree.GetItems(), ExpandedPhasesList);
	
	PhaseTreeDragServer(SourceRef, ReceiverRef);
	
	ProjectManagementClient.SetTreeItemsExpanded(Items.PhaseTree, PhaseTree, ExpandedPhasesList);
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, SourceRef);
	
	SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items);
	
EndProcedure

&AtClient
Procedure PhaseNameOnChange(Item)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.Description = CurrentData.PhaseName;
	
EndProcedure

&AtServer
Function GetNextPhasesOfPhases(PhasesArray)
	
	NextPhasesArray = New Array;
	
	For Each PhaseItem In PhasesArray Do
		
		NextPhasesTable = ProjectManagement.GetAllNextPhases(PhaseItem, False);
		
		For Each NextPhaseRow In NextPhasesTable Do
			If NextPhasesArray.Find(NextPhaseRow.Ref) = Undefined Then
				NextPhasesArray.Add(NextPhaseRow.Ref);
			EndIf;
		EndDo;
		
	EndDo;
	
	Return NextPhasesArray;
	
EndFunction

&AtClient
Procedure StartDateOnChange(Item)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	StartDateOnChangeHandler(CurrentData);
	
EndProcedure

&AtClient
Procedure StartDateOnChangeHandler(CurrentData)
	
	If ValueIsFilled(CurrentData.StartDate) 
		And CurrentData.StartDate = BegOfDay(CurrentData.StartDate)
		And ProjectAttributes.UseWorkSchedule Then
		
		WorkSchedule = ?(ValueIsFilled(CurrentData.WorkSchedule),
			CurrentData.WorkSchedule,
			ProjectAttributes.WorkSchedule);
		
		CurrentData.StartDate = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(WorkSchedule, CurrentData.StartDate);
		
	EndIf;
	
	If Not ValueIsFilled(CurrentData.StartDate) Then
		CurrentData.Duration = 0;
	ElsIf Not ValueIsFilled(CurrentData.Duration) Then
		CurrentData.EndDate = CurrentData.StartDate;
	ElsIf ValueIsFilled(CurrentData.Duration) Then
		
		ProjectPhaseStructure = New Structure;
		ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
		ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
		
		CurrentData.EndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
			CurrentData.StartDate,
			CurrentData.Duration,
			CurrentData.DurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EndDateOnChangeHandler(CurrentData);
	
EndProcedure

&AtClient
Procedure EndDateOnChangeHandler(CurrentData)
	
	If ValueIsFilled(CurrentData.EndDate)
		And CurrentData.EndDate = BegOfDay(CurrentData.EndDate)
		And ProjectAttributes.UseWorkSchedule Then
		
		WorkSchedule = ?(ValueIsFilled(CurrentData.WorkSchedule),
			CurrentData.WorkSchedule,
			ProjectAttributes.WorkSchedule);
		
		CurrentData.EndDate = WorkSchedulesDrive.GetLastWorkingTimeOfDay(WorkSchedule, CurrentData.EndDate);
		
	EndIf;
	
	If Not ValueIsFilled(CurrentData.EndDate) Then
		CurrentData.Duration = 0;
	ElsIf Not ValueIsFilled(CurrentData.Duration) Then
		CurrentData.StartDate = CurrentData.EndDate;
	ElsIf ValueIsFilled(CurrentData.StartDate) Then
		
		ProjectPhaseStructure = New Structure;
		ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
		ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
		
		CurrentData.Duration = ProjectManagement.CalculatePeriodDuration(ProjectPhaseStructure,
			CurrentData.StartDate,
			CurrentData.EndDate,
			CurrentData.DurationUnit);
		
		DurationPresentation = GetDurationPresentation(CurrentData.DurationUnit);
		CurrentData.DurationStr = String(CurrentData.Duration) + " " + DurationPresentation;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DurationStrOnChange(Item)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DurationStrOnChangeHandler(CurrentData);
	
EndProcedure

&AtClient
Procedure DurationStrOnChangeHandler(CurrentData)
	
	DurationBeforeChanging = CurrentData.Duration;
	Try
		NumberPart = GetNumberPart(CurrentData.DurationStr);
		Duration = Number(NumberPart);
	Except
		CommonClientServer.MessageToUser(NStr("en = 'Duration must be a positive integer.'; ru = 'Длительность должна быть положительным целым числом.';pl = 'Czas trwania musi być dodatnią liczbą całkowitą.';es_ES = 'La duración debe ser un número entero positivo.';es_CO = 'La duración debe ser un número entero positivo.';tr = 'Süre, pozitif bir tam sayı olmalıdır.';it = 'La durata deve essere un numero intero positivo.';de = 'Dauer soll eine positive ganze Zahl sein.'"));
		CurrentData.DurationStr = DurationBeforeChanging;
		Return;
	EndTry;
	
	CurrentData.Duration = Duration;
	
	DurationPresentation = GetDurationPresentation(CurrentData.DurationUnit);
	CurrentData.DurationStr = String(CurrentData.Duration) + " " + DurationPresentation;
	
	ProjectPhaseStructure = New Structure;
	ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
	ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
	
	If ValueIsFilled(CurrentData.StartDate) Then
		CurrentData.EndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
			CurrentData.StartDate,
			CurrentData.Duration,
			CurrentData.DurationUnit);
	EndIf;
	
EndProcedure

&AtClient
Procedure DurationStrTuning(Item, Direction, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DurationStrTuningHandler(CurrentData, Direction);
	
EndProcedure

&AtClient
Procedure DurationStrTuningHandler(CurrentData, Direction)
	
	CurrentData.Duration = CurrentData.Duration + Direction;
	
	DurationPresentation = GetDurationPresentation(CurrentData.DurationUnit);
	CurrentData.DurationStr = String(CurrentData.Duration) + " " + DurationPresentation;
	
	ProjectPhaseStructure = New Structure;
	ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
	ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
	
	If ValueIsFilled(CurrentData.StartDate) Then 
		CurrentData.EndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
			CurrentData.StartDate,
			CurrentData.Duration,
			CurrentData.DurationUnit);
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualDurationStrOnChange(Item)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	BeginDuration = CurrentData.ActualDuration;
	Try
		NumberPart = GetNumberPart(CurrentData.ActualDurationStr);
		ActualDuration = Number(NumberPart);
	Except
		CommonClientServer.MessageToUser(NStr("en = 'Duration must be a positive integer.'; ru = 'Длительность должна быть положительным целым числом.';pl = 'Czas trwania musi być dodatnią liczbą całkowitą.';es_ES = 'La duración debe ser un número entero positivo.';es_CO = 'La duración debe ser un número entero positivo.';tr = 'Süre, pozitif bir tam sayı olmalıdır.';it = 'La durata deve essere un numero intero positivo.';de = 'Dauer soll eine positive ganze Zahl sein.'"));
		CurrentData.ActualDurationStr = BeginDuration;
		Return;
	EndTry;
	
	CurrentData.ActualDuration = ActualDuration;
	
	If CurrentData.ActualDuration > 0 Then
		ActualDurationPresentation = GetDurationPresentation(CurrentData.ActualDurationUnit);
		CurrentData.ActualDurationStr = String(CurrentData.ActualDuration) + " " + ActualDurationPresentation;
	Else
		CurrentData.ActualDurationStr = "";
	EndIf;
	
	If ValueIsFilled(CurrentData.ActualStartDate) Then
		
		ProjectPhaseStructure = New Structure;
		ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
		ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
		
		CurrentData.ActualEndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
			CurrentData.ActualStartDate,
			CurrentData.ActualDuration,
			CurrentData.ActualDurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualDurationStrTuning(Item, Direction, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ActualDuration = CurrentData.ActualDuration;
	
	CurrentData.ActualDuration = ActualDuration + Direction;
	
	If CurrentData.ActualDuration > 0 Then
		ActualDurationPresentation = GetDurationPresentation(CurrentData.ActualDurationUnit);
		CurrentData.ActualDurationStr = String(CurrentData.ActualDuration) + " " + ActualDurationPresentation;
	Else
		CurrentData.ActualDurationStr = "";
	EndIf;
	
	If ValueIsFilled(CurrentData.ActualStartDate) Then 
		
		ProjectPhaseStructure = New Structure;
		ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
		ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
		
		CurrentData.ActualEndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
			CurrentData.ActualStartDate,
			CurrentData.ActualDuration,
			CurrentData.ActualDurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualStartDateOnChange(Item)
	
	ProcessActualStartDateChange();
	
EndProcedure

&AtClient
Procedure ActualEndDateOnChange(Item)
	
	ProcessActualEndDateChange();
	
EndProcedure

&AtClient
Procedure MainTasksBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.MainTasks.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CheckResult = ProjectManagement.CheckProjectPhaseNewStatus(CurrentData.Status, CurrentData.Ref);
	
	If CheckResult.Checked Then
		
		If CheckResult.PrevStatus <> CurrentData.Status Then
			
			If CurrentData.Status = PredefinedValue("Enum.ProjectPhaseStatuses.InProgress") Then
				
				CurrentData.ActualStartDate = DriveReUse.GetSessionCurrentDate();
				ProcessActualStartDateChange(CurrentData);
				
				If CheckResult.PrevStatus = PredefinedValue("Enum.ProjectPhaseStatuses.Completed") Then
					CurrentData.ActualEndDate = Date(1, 1, 1);
					CurrentData.ActualDuration = 0;
				EndIf;
				
			ElsIf CurrentData.Status = PredefinedValue("Enum.ProjectPhaseStatuses.Completed") Then
				
				CurrentData.ActualEndDate = DriveReUse.GetSessionCurrentDate();
				ProcessActualEndDateChange(CurrentData);
				
			ElsIf CurrentData.Status = PredefinedValue("Enum.ProjectPhaseStatuses.Open") Then
				
				If CheckResult.PrevStatus = PredefinedValue("Enum.ProjectPhaseStatuses.InProgress") Then
					CurrentData.ActualStartDate = Date(1, 1, 1);
					CurrentData.ActualEndDate = Date(1, 1, 1);
					CurrentData.ActualDuration = 0;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		SetEnableActualAttributes(CurrentData);
		SetEnableByStatus();
		
	Else
		
		If CheckResult.IsQuery Then
			NotifyDescription = New NotifyDescription("CheckProjectPhaseNewStatusEnd",
				ThisObject,
				New Structure("PrevStatus, CurrentData", CheckResult.PrevStatus, CurrentData));
			ShowQueryBox(NotifyDescription, CheckResult.MessageText, QuestionDialogMode.YesNo);
			Return;
		Else
			
			CommonClientServer.MessageToUser(CheckResult.MessageText);
			
		EndIf;
		
		CurrentData.Status = CheckResult.PrevStatus;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdatePhaseTree();
	
EndProcedure

&AtClient
Procedure StuckPhases(Command)
	
	FilterStructure = New Structure("Project, Company", Project, ProjectAttributes.Company);
	
	FormParameters = New Structure;
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("VariantKey", "StuckPhases");
	FormParameters.Insert("Filter", FilterStructure);
	
	OpenForm("Report.ProjectPhases.Form", FormParameters, ThisObject, True);
	
EndProcedure

&AtClient
Procedure LateStart(Command)
	
	FilterStructure = New Structure("Project, Company", Project, ProjectAttributes.Company);
	
	FormParameters = New Structure;
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("VariantKey", "LateStart");
	FormParameters.Insert("Filter", FilterStructure);
	
	OpenForm("Report.ProjectPhases.Form", FormParameters, ThisObject, True);
	
EndProcedure

&AtClient
Procedure ConnectPhases(Command)
	
	If Items.PhaseTree.SelectedRows.Count() <> 2 Then
		CommonClientServer.MessageToUser(NStr("en = 'Cannot perform the action.The action is applicable only to two phases.
			|The action sets one of them as the previous phase for the other.
			|Select two phases, right-click the selected phase that requires a previous phase, and select the action.'; 
			|ru = 'Не удалось выполнить действие. Действие применимо только к двум этапам.
			| Оно устанавливает один из этих этапов в качестве предыдущего этапа для второго.
			|Выберите два этапа, щелкните правой кнопкой мыши по этапу, для которого требуется указать предыдущий этап, и выберите действие.';
			|pl = 'Nie można wykonać działania. Działanie dotyczy tylko dwóch etapów.
			|Działanie ustawi jeden z nich jako poprzedni etap dla drugiego.
			|Wybierz dwa etapy, kliknij prawym przyciskiem myszy wybrany etap, który wymaga poprzedniego etapu i wybierz działanie.';
			|es_ES = 'No se puede realizar la acción. La acción sólo es aplicable a dos fases.
			|La acción establece una de ellas como fase anterior para la otra.
			|Seleccione dos fases, haga clic con el botón derecho en la fase seleccionada que requiere una fase anterior y seleccione la acción.';
			|es_CO = 'No se puede realizar la acción. La acción sólo es aplicable a dos fases.
			|La acción establece una de ellas como fase anterior para la otra.
			|Seleccione dos fases, haga clic con el botón derecho en la fase seleccionada que requiere una fase anterior y seleccione la acción.';
			|tr = 'İşlem gerçekleştirilemiyor. İşlem sadece iki evreye uygulanabilir.
			|İşlem, evrelerden birini diğerinin öncülü olarak ayarlar.
			|İki evre seçin, öncül gerektiren evreye sağ tıklayın ve işlemi seçim.';
			|it = 'Impossibile eseguire l''azione. L''azione è applicabile solo a due fasi.
			|L''azione imposta una fase come precedente rispetto all''altra.
			|Selezionare due fasi, cliccare con il tasto destro del mouse sulla fase selezionata che richiede una fase precedente e selezionare l''azione.';
			|de = 'Die Aktion ist nicht ausführbar. Die Aktion ist nur für zwei Phasen anwenbar.
			| Die Aktion macht eine davon der anderen vorgesetzt.
			| Wählen Sie zwei Phasen aus, klicken Sie mit der rechten Maustaste auf die ausgewählte Phase, die eine Vorphase erfordert, und wählen Sie dann die Aktion aus.'"));
		Return;
	EndIf;
	
	CurrentData = Items.PhaseTree.CurrentData;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'For phase ""%1"", the previous phase was set.'; ru = 'Для этапа""%1"" был задан предыдущий этап.';pl = 'Dla etapu ""%1"", poprzedni etap został ustawiony.';es_ES = 'Para la fase ""%1"", se ha establecido la fase anterior.';es_CO = 'Para la fase ""%1"", se ha establecido la fase anterior.';tr = '""%1"" evresi için önceki evre ayarlandı.';it = 'Per la fase ""%1"" è stata impostata la fase precedente.';de = 'Die Vorphase ist für die Phase ""%1"" vordefiniert.'"),
		CurrentData.PhaseName);
	
	Result = ConnectPhasesServer();
	
	If Result Then
		ShowUserNotification(
			NStr("en = 'Previous phase setting'; ru = 'Настройка предыдущего этапа';pl = 'Ustawienie poprzedniego etapu';es_ES = 'Configuración de la fase anterior';es_CO = 'Configuración de la fase anterior';tr = 'Önceki evre ayarı';it = 'Impostazione fase precedente';de = 'Einstellung der Vorphase'"),
			GetURL(CurrentData.Ref),
			MessageText,
			PictureLib.Information32);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPhase(Command)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", CurrentData.Ref);
	
	OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ShowMarkedToDelete(Command)
	
	ShowMarkedToDelete = Not ShowMarkedToDelete;
	Items.PhaseTreeShowMarkedToDelete.Check = ShowMarkedToDelete;
	
	ExpandedPhasesList.Clear();
	ProjectManagementClient.GetExpandedPhasesArray(Items.PhaseTree, PhaseTree.GetItems(), ExpandedPhasesList);
	TempCurrentProjectPhase = CurrentProjectPhase;
	
	FillInPhaseTree();
	ProjectManagementClient.SetTreeItemsExpanded(Items.PhaseTree, PhaseTree, ExpandedPhasesList);
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, TempCurrentProjectPhase);
	
EndProcedure

&AtClient
Procedure EditInList(Command)
	
	EditOption = "InList";
	SetAvailabilityOfPhaseTreeFields(EditOption);
	
EndProcedure

&AtClient
Procedure EditInCard(Command)
	
	EditOption = "InDialog";
	SetAvailabilityOfPhaseTreeFields(EditOption);
	
EndProcedure

&AtClient
Procedure OpenProject(Command)
	
	ShowValue(, Project);
	
EndProcedure

&AtClient
Procedure OpenMainProcess(Command)
	
	CurrentData = Items.MainTasks.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	ShowValue(, CurrentData.BusinessProcess);
	
EndProcedure

&AtClient
Procedure ShowProcessesTasks(Command)
	
	ShowProcessesTasks = Not ShowProcessesTasks;
	Items.GroupTasks.Visible = ShowProcessesTasks;
	Items.PhaseTreeShowProcessesTasks.Check = ShowProcessesTasks;
	
EndProcedure

&AtClient
Procedure AddSubordinate(Command)
	
	If Not ProjectAttributes.IsAvailableForModification Then
		MessageText = ProjectManagementClientServer.NoRightsEditMessageText();
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If ProjectAttributes.ProjectCompeted Then
		MessageText = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
		CommonClientServer.MessageToUser(MessageText);
		CancelEdit = True;
		Return;
	EndIf;
	
	If EditOption = "InList" Then
		
		CurrentRow = Items.PhaseTree.CurrentRow;
		If CurrentRow = Undefined Then
			NewItem = PhaseTree.GetItems().Add();
		Else
			TreeItem = PhaseTree.FindByID(CurrentRow);
			NewItem = TreeItem.GetItems().Add();
		EndIf;
		
		Items.PhaseTree.CurrentRow = NewItem.GetID();
		Items.PhaseTree.ChangeRow();
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("Project", Project);
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData <> Undefined Then
			FormParameters.Insert("Parent", CurrentData.Ref);
		EndIf;
		
		OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddNext(Command)
	
	If Not ProjectAttributes.IsAvailableForModification Then
		MessageText = ProjectManagementClientServer.NoRightsEditMessageText();
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	If ProjectAttributes.ProjectCompeted Then
		MessageText = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
		CommonClientServer.MessageToUser(MessageText);
		CancelEdit = True;
		Return;
	EndIf;
	
	If EditOption = "InList" Then
		
		CurrentRow = Items.PhaseTree.CurrentRow;
		If CurrentRow = Undefined Then
			NewItem = PhaseTree.GetItems().Add();
		Else
			TreeItem = PhaseTree.FindByID(CurrentRow);
			ItemParent = TreeItem.GetParent();
			
			If ItemParent = Undefined Then
				NewItem = PhaseTree.GetItems().Add();
			Else
				NewItem = ItemParent.GetItems().Add();
			EndIf;
			
			NewItem.PreviousPhase = TreeItem.Ref;
			
		EndIf;
		
		Items.PhaseTree.CurrentRow = NewItem.GetID();
		Items.PhaseTree.ChangeRow();
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("Project", Project);
		
		CurrentData = Items.PhaseTree.CurrentData;
		If CurrentData <> Undefined Then 
			FormParameters.Insert("Parent", CurrentData.ParentPhase);
			FormParameters.Insert("PreviousPhase", CurrentData.Ref);
		EndIf;
		
		OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LevelDown(Command)
	
	If Items.PhaseTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExpandedPhasesList.Clear();
	
	ProjectManagementClient.GetExpandedPhasesArray(Items.PhaseTree, PhaseTree.GetItems(), ExpandedPhasesList);
	
	CurrentProjectPhaseBeforeTransfer = CurrentProjectPhase;
	
	SelectedPhasesArray = New Array;
	For Each SelectedRow In Items.PhaseTree.SelectedRows Do
		PhaseRef = PhaseTree.FindByID(SelectedRow).Ref;
		SelectedPhasesArray.Add(PhaseRef);
	EndDo;
	
	LevelDownServer(Items.PhaseTree.CurrentData.Ref, Items.PhaseTree.CurrentData.ParentPhase);
	
	ProjectManagementClient.SetTreeItemsExpanded(Items.PhaseTree, PhaseTree, ExpandedPhasesList);
	
	Items.PhaseTree.SelectedRows.Clear();
	
	For Each PhaseRef In SelectedPhasesArray Do
		ProjectManagementClient.SetSelectedPhaseInTreeByRef(Items.PhaseTree, PhaseTree, PhaseRef);
	EndDo;
	
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, CurrentProjectPhaseBeforeTransfer);
	
	SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items);
	
EndProcedure

&AtClient
Procedure LevelUp(Command)
	
	If Items.PhaseTree.CurrentData = Undefined 
		Or Not ValueIsFilled(Items.PhaseTree.CurrentData.ParentPhase) Then
		Return;
	EndIf;
	
	ExpandedPhasesList.Clear();
	
	ProjectManagementClient.GetExpandedPhasesArray(Items.PhaseTree, PhaseTree.GetItems(), ExpandedPhasesList);
	
	CurrentProjectPhaseBeforeTransfer = CurrentProjectPhase;
	
	SelectedPhasesArray = New Array;
	For Each SelectedRow In Items.PhaseTree.SelectedRows Do
		PhaseRef = PhaseTree.FindByID(SelectedRow).Ref;
		SelectedPhasesArray.Add(PhaseRef);
	EndDo;
	
	LevelUpServer(Items.PhaseTree.CurrentData.Ref, Items.PhaseTree.CurrentData.ParentPhase);
	
	ProjectManagementClient.SetTreeItemsExpanded(Items.PhaseTree, PhaseTree, ExpandedPhasesList);
	
	Items.PhaseTree.SelectedRows.Clear();
	For Each PhaseRef In SelectedPhasesArray Do
		ProjectManagementClient.SetSelectedPhaseInTreeByRef(Items.PhaseTree, PhaseTree, PhaseRef);
	EndDo;
	
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, CurrentProjectPhaseBeforeTransfer);
	SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items);
	
EndProcedure

&AtClient
Procedure Up(Command)
	
	If Items.PhaseTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentProjectPhaseBeforeTransfer = CurrentProjectPhase;
	
	SelectedPhasesArray = New Array;
	For Each SelectedRow In Items.PhaseTree.SelectedRows Do
		PhaseRef = PhaseTree.FindByID(SelectedRow).Ref;
		SelectedPhasesArray.Add(PhaseRef);
	EndDo;
	
	UpServer();
	
	Items.PhaseTree.SelectedRows.Clear();
	For Each PhaseRef In SelectedPhasesArray Do
		ProjectManagementClient.SetSelectedPhaseInTreeByRef(Items.PhaseTree, PhaseTree, PhaseRef);
	EndDo;
	
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, CurrentProjectPhaseBeforeTransfer);
	
EndProcedure

&AtClient
Procedure Down(Command)
	
	If Items.PhaseTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentProjectPhaseBeforeTransfer = CurrentProjectPhase;
	
	SelectedPhasesArray = New Array;
	For Each SelectedRow In Items.PhaseTree.SelectedRows Do
		PhaseRef = PhaseTree.FindByID(SelectedRow).Ref;
		SelectedPhasesArray.Add(PhaseRef);
	EndDo;
	
	DownServer();
	
	Items.PhaseTree.SelectedRows.Clear();
	For Each PhaseRef In SelectedPhasesArray Do
		ProjectManagementClient.SetSelectedPhaseInTreeByRef(Items.PhaseTree, PhaseTree, PhaseRef);
	EndDo;
	
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, CurrentProjectPhaseBeforeTransfer);
	
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.PhaseTree);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.PhaseTree, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.PhaseTree);
EndProcedure
// End StandardSubsystems.AttachableCommands

&AtClient
Procedure ShowSubphases(Command)
	
	CurrentRow = Items.PhaseTree.CurrentRow;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	Items.PhaseTree.Expand(CurrentRow, True);
	
EndProcedure

&AtClient
Procedure HideSubphases(Command)
	
	CurrentRow = Items.PhaseTree.CurrentRow;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	Items.PhaseTree.Collapse(CurrentRow);
	
EndProcedure

&AtClient
Procedure Level1(Command)
	
	ShowLevel(1);
	
EndProcedure

&AtClient
Procedure Level2(Command)
	
	ShowLevel(2);
	
EndProcedure

&AtClient
Procedure Level3(Command)
	
	ShowLevel(3);
	
EndProcedure

&AtClient
Procedure Level4(Command)
	
	ShowLevel(4);
	
EndProcedure

&AtClient
Procedure Level5(Command)
	
	ShowLevel(5);
	
EndProcedure

&AtClient
Procedure Level6(Command)
	
	ShowLevel(6);
	
EndProcedure

&AtClient
Procedure Level7(Command)
	
	ShowLevel(7);
	
EndProcedure

&AtClient
Procedure LoadFromTemplate(Command)
	
	ProjectManagementClient.LoadProjectFromTemplate(Project);
	
EndProcedure

&AtClient
Procedure SaveTemplate(Command)
	
	OpenForm("Catalog.ProjectTemplates.ObjectForm", New Structure("Basis", Project));
	
EndProcedure

&AtClient
Procedure CreateTask(Command)
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("BusinessProcess.ProjectJob.ObjectForm", New Structure("Basis", CurrentData.Ref));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVisibility(Mode)
	
	Items.GroupPages.CurrentPage = Items.GroupProjectPhases;
	
	Items.GroupActual.ShowInHeader = False;
	Items.GroupPlan.ShowInHeader = False;
	
	Items.StartDate.Title = NStr("en = 'Start'; ru = 'Начало';pl = 'Rozpoczęcie';es_ES = 'Iniciar';es_CO = 'Inicio';tr = 'Başlangıç';it = 'Inizio';de = 'Start'");
	Items.DurationStr.Title = NStr("en = 'Duration'; ru = 'Длительность';pl = 'Czas trwania';es_ES = 'Duración';es_CO = 'Duración';tr = 'Süre';it = 'Durata';de = 'Dauer'");
	Items.EndDate.Title = NStr("en = 'End'; ru = 'Окончание';pl = 'Zakończenie';es_ES = 'Fin';es_CO = 'Fin';tr = 'Bitiş';it = 'Fine';de = 'Ende'");
	
	Items.ActualStartDate.Title = NStr("en = 'Start'; ru = 'Начало';pl = 'Rozpoczęcie';es_ES = 'Iniciar';es_CO = 'Inicio';tr = 'Başlangıç';it = 'Inizio';de = 'Start'");
	Items.ActualDurationStr.Title = NStr("en = 'Duration'; ru = 'Длительность';pl = 'Czas trwania';es_ES = 'Duración';es_CO = 'Duración';tr = 'Süre';it = 'Durata';de = 'Dauer'");
	Items.ActualEndDate.Title = NStr("en = 'End'; ru = 'Окончание';pl = 'Zakończenie';es_ES = 'Fin';es_CO = 'Fin';tr = 'Bitiş';it = 'Fine';de = 'Ende'");
	
	Items.Status.Visible = True;
	Items.Executor.Visible = True;
	Items.PreviousPhase.Visible = True;
	
	Items.Tasks.FixingInTable = FixingInTable.None;
	Items.PhaseName.FixingInTable = FixingInTable.None;
	
	If Mode = "Planning" Then 
		
		Items.StartDate.Visible = True;
		Items.DurationStr.Visible = True;
		Items.EndDate.Visible = True;
		
		Items.ActualStartDate.Visible = False;
		Items.ActualDurationStr.Visible = False;
		Items.ActualEndDate.Visible = False;
		
		Items.Status.Visible = False;
		
	ElsIf Mode = "ForExecution" Then 
		
		Items.StartDate.Visible = True;
		Items.StartDate.Title = NStr("en = 'Start (plan)'; ru = 'Начало (план)';pl = 'Rozpoczęcie (planowane)';es_ES = 'Iniciar (plan)';es_CO = 'Iniciar (plan)';tr = 'Başlangıç (planlanan)';it = 'Avvio (secondo il piano)';de = 'Start (Plan)'");
		Items.DurationStr.Visible = False;
		Items.EndDate.Visible = False;
		
		Items.ActualStartDate.Visible = True;
		Items.ActualStartDate.Title = NStr("en = 'Start (actual)'; ru = 'Начало (факт)';pl = 'Rozpoczęcie (faktyczne)';es_ES = 'Iniciar (real)';es_CO = 'Iniciar (real)';tr = 'Başlangıç (gerçekleşen)';it = 'Avvio (effettivo)';de = 'Start (aktuell)'");
		Items.ActualDurationStr.Visible = False;
		Items.ActualEndDate.Visible = False;
		
		Items.PreviousPhase.Visible = False;
		
	ElsIf Mode = "ExecutionControl" Then 
		
		Items.DurationStr.Visible = False;
		Items.StartDate.Visible = False;
		Items.EndDate.Visible = True;
		Items.EndDate.Title = NStr("en = 'End (plan)'; ru = 'Завершение (план)';pl = 'Zakończenie (planowane)';es_ES = 'Fin (plan)';es_CO = 'Fin (plan)';tr = 'Bitiş (planlanan)';it = 'Fine (programmata)';de = 'Ende (Plan)'");
		
		Items.ActualStartDate.Visible = False;
		Items.ActualDurationStr.Visible = False;
		Items.ActualEndDate.Visible = True;
		Items.ActualEndDate.Title = NStr("en = 'End (actual)'; ru = 'Завершение (факт)';pl = 'Zakończenie (faktyczne)';es_ES = 'Fin (real)';es_CO = 'Fin (real)';tr = 'Bitiş (gerçekleşen)';it = 'Fine (effettiva)';de = 'Ende (aktuelle)'");
		
		Items.PreviousPhase.Visible = False;
		
	ElsIf Mode = "Full" Then 
		
		Items.GroupActual.ShowInHeader = True;
		Items.GroupPlan.ShowInHeader = True;
		
		Items.DurationStr.Visible = True;
		Items.StartDate.Visible = True;
		Items.EndDate.Visible = True;
		
		Items.ActualStartDate.Visible = True;
		Items.ActualDurationStr.Visible = True;
		Items.ActualEndDate.Visible = True;
		
		Items.Tasks.FixingInTable = FixingInTable.Left;
		Items.PhaseName.FixingInTable = FixingInTable.Left;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInPhaseTree()
	
	Tree = FormAttributeToValue("PhaseTree");
	Tree.Rows.Clear();
	
	If ValueIsFilled(Project) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	PerformerTask.Topic AS Topic,
		|	PerformerTask.Executed AS Executed,
		|	PerformerTask.DeletionMark AS DeletionMark
		|INTO TasksTopics
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	VALUETYPE(PerformerTask.Topic) = TYPE(Catalog.ProjectPhases)
		|
		|INDEX BY
		|	Topic,
		|	Executed,
		|	DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	PerformerTask.ProjectPhase AS ProjectPhase,
		|	PerformerTask.Executed AS Executed,
		|	PerformerTask.DeletionMark AS DeletionMark
		|INTO Tasks
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.Project = &Project
		|
		|INDEX BY
		|	PerformerTask.ProjectPhase,
		|	PerformerTask.Executed,
		|	PerformerTask.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ProjectPhases.Ref AS Ref,
		|	ProjectPhases.DataVersion AS DataVersion,
		|	ProjectPhases.Parent AS Parent,
		|	ProjectPhases.SummaryPhase AS SummaryPhase,
		|	ProjectPhases.DeletionMark AS DeletionMark,
		|	ProjectPhases.Description AS Description,
		|	ProjectPhases.CodeWBS AS CodeWBS,
		|	ProjectPhases.Owner AS Owner,
		|	ProjectPhases.PreviousPhase AS PreviousPhase,
		|	ProjectPhases.Executor AS Executor,
		|	Projects.DurationUnit AS DurationUnit,
		|	Projects.DurationUnit AS ActualDurationUnit,
		|	Projects.WorkSchedule AS WorkSchedule,
		|	ProjectPhases.Status AS Status,
		|	ISNULL(ProjectPhasesTimelines.StartDate, DATETIME(1, 1, 1)) AS StartDate,
		|	ISNULL(ProjectPhasesTimelines.EndDate, DATETIME(1, 1, 1)) AS EndDate,
		|	ISNULL(ProjectPhasesTimelines.Duration, 0) AS Duration,
		|	ISNULL(ProjectPhasesTimelines.ActualStartDate, DATETIME(1, 1, 1)) AS ActualStartDate,
		|	ISNULL(ProjectPhasesTimelines.ActualEndDate, DATETIME(1, 1, 1)) AS ActualEndDate,
		|	ISNULL(ProjectPhasesTimelines.ActualDuration, 0) AS ActualDuration,
		|	CASE
		|		WHEN TRUE IN
		|				(SELECT TOP 1
		|					TRUE
		|				FROM
		|					Tasks AS Tasks
		|				WHERE
		|					ProjectPhases.Ref = Tasks.ProjectPhase
		|					AND NOT Tasks.DeletionMark
		|					AND NOT Tasks.Executed
		|	
		|				UNION ALL
		|	
		|				SELECT TOP 1
		|					TRUE
		|				FROM
		|					TasksTopics AS TasksTopics
		|				WHERE
		|					ProjectPhases.Ref = TasksTopics.Topic
		|					AND NOT TasksTopics.DeletionMark
		|					AND NOT TasksTopics.Executed)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS TasksExist
		|FROM
		|	Catalog.Projects AS Projects
		|		INNER JOIN Catalog.ProjectPhases AS ProjectPhases
		|		ON Projects.Ref = ProjectPhases.Owner
		|		LEFT JOIN InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
		|		ON (ProjectPhases.Ref = ProjectPhasesTimelines.ProjectPhase)
		|WHERE
		|	Projects.Ref = &Project
		|
		|ORDER BY
		|	ProjectPhases.PhaseNumberInLevel HIERARCHY";
		
		Query.SetParameter("Project", Project);
		Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
		
		Result = Query.Execute();
		Selection = Result.Select();
		CurrentDate = CurrentSessionDate();
		
		While Selection.Next() Do
			
			If Selection.DeletionMark And Not ShowMarkedToDelete Then
				Continue;
			EndIf;
			
			If ValueIsFilled(StateOfProjectPhases) And StateOfProjectPhases <> "All" Then
				
				If Not Selection.SummaryPhase Then
					
					If StateOfProjectPhases = "Completed" Then
						
						If Selection.Status <> Enums.ProjectPhaseStatuses.Completed Then
							Continue;
						EndIf;
						
					ElsIf StateOfProjectPhases = "NotCompleted" Then
						
						If Selection.Status = Enums.ProjectPhaseStatuses.Completed Then
							Continue;
						EndIf;
						
					ElsIf StateOfProjectPhases = "NotStartedOnTime" Then
						
						If Not ValueIsFilled(Selection.ActualStartDate) And Selection.StartDate < CurrentDate Then
						Else
							Continue;
						EndIf;
						
					ElsIf StateOfProjectPhases = "StartTimeHasNotCome" Then
						
						If Not ValueIsFilled(Selection.ActualStartDate) And Selection.StartDate >= CurrentDate Then
						Else
							Continue;
						EndIf;
						
					ElsIf StateOfProjectPhases = "PerformedWithDelay" Then
						
						If ValueIsFilled(Selection.ActualStartDate) And Not ValueIsFilled(Selection.ActualEndDate)
							And Selection.EndDate < CurrentDate Then
						Else
							Continue;
						EndIf;
						
					ElsIf StateOfProjectPhases = "PerformedWithoutDelay" Then
						
						If ValueIsFilled(Selection.ActualStartDate) And Not ValueIsFilled(Selection.ActualEndDate) 
							And Selection.EndDate >= CurrentDate Then
						Else
							Continue;
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(ByExecutor) And Not Selection.SummaryPhase Then
				
				If ByExecutor <> Selection.Executor Then
					Continue;
				EndIf;
				
			EndIf;
			
			Parent = Selection.Parent;
			If Not ValueIsFilled(Parent) Then
				NewRow = Tree.Rows.Add();
			Else
				FoundRow = Tree.Rows.Find(Parent, "Ref", True);
				NewRow = FoundRow.Rows.Add();
			EndIf;
			
			NewRow.Tasks = Selection.TasksExist;
			NewRow.CurrentDate = CurrentDate;
			
			FillInTreeRowFromPhase(NewRow, Selection);
			
		EndDo;
		
		If (ValueIsFilled(StateOfProjectPhases) And StateOfProjectPhases <> "All")
			Or ValueIsFilled(ByExecutor) Then
			DeleteSummaryRowsWithoutSubordinates(Tree);
		EndIf;
		
	EndIf;
	
	ValueToFormAttribute(Tree, "PhaseTree");
	
	Index = -1;
	ProjectManagementClientServer.FindPhaseInTreeByRef(PhaseTree.GetItems(), CurrentProjectPhase, Index);
	If Index > -1 Then
		Items.PhaseTree.CurrentRow = Index;
	EndIf;
	
EndProcedure

&AtServer
Function DeleteSummaryRowsWithoutSubordinates(Tree, CurrentRow = Undefined)
	
	If CurrentRow = Undefined Then
		CurrentRow = Tree;
	EndIf;
	
	RowsCount = CurrentRow.Rows.Count();
	
	AllSummary = True;
	
	Idx = 1;
	While Idx <= RowsCount Do
		
		Row = CurrentRow.Rows[RowsCount - Idx];
		If Row.SummaryPhase Then
			If Not DeleteSummaryRowsWithoutSubordinates(Tree, Row) Then
				AllSummary = False;
			EndIf;
		Else
			AllSummary = False;
		EndIf;
		
		Idx = Idx + 1;
		
	EndDo;
	
	If AllSummary Then
		
		If CurrentRow <> Tree Then
			If CurrentRow.SummaryPhase Then
				
				If ValueIsFilled(CurrentRow.Parent) Then
					CurrentRow.Parent.Rows.Delete(CurrentRow);
				Else
					Tree.Rows.Delete(CurrentRow);
				EndIf;
				
			EndIf;
		EndIf;
		
	EndIf;
	
	Return AllSummary;
	
EndFunction

&AtServer
Procedure FillInTreeRowFromPhase(TreeItem, ProjectPhase)
	
	If TypeOf(TreeItem) = Type("Number") Then 
		TreeItem = PhaseTree.FindByID(TreeItem);
	EndIf;
	
	AttributesList1 = 
	"Description,
	|Parent,
	|Executor,
	|PreviousPhase,
	|CodeWBS,
	|Owner,
	|Ref,
	|DataVersion,
	|Status,
	|DeletionMark,
	|SummaryPhase";
	
	AttributesList2 = 
	"StartDate,
	|EndDate,
	|Duration,
	|DurationUnit,
	|ActualStartDate,
	|ActualEndDate,
	|ActualDuration,
	|ActualDurationUnit,
	|WorkSchedule";
	
	If TypeOf(ProjectPhase) = Type("CatalogRef.ProjectPhases") Then
		
		Attributes = Common.ObjectAttributesValues(ProjectPhase, AttributesList1);
		
		ProjectPhaseData = ProjectManagement.GetPhaseData(ProjectPhase);
		AttributesStructure2 = New Structure(AttributesList2);
		For Each Row In AttributesStructure2 Do
			Attributes.Insert(Row.Key, ProjectPhaseData[Row.Key]);
		EndDo;
		
	Else
		Attributes = ProjectPhase;
	EndIf;
	
	AttributesList = AttributesList1 + "," + AttributesList2;
	AttributesList = StrReplace(AttributesList, "Parent,", "");
	
	FillPropertyValues(TreeItem, Attributes, AttributesList);
	
	TreeItem.PictureIndex = ?(TreeItem.DeletionMark, 3, 2);
	TreeItem.ParentPhase = Attributes.Parent;
	TreeItem.PhaseName = Attributes.CodeWBS + "  " + Attributes.Description;
	
	DurationPresentation = GetDurationPresentation(Attributes.DurationUnit);
	TreeItem.DurationStr = String(Attributes.Duration) + " " + DurationPresentation;
	
	TreeItem.ActualDurationStr = "";
	If Attributes.ActualDuration > 0 Then
		ActualDurationPresentation = GetDurationPresentation(Attributes.ActualDurationUnit);
		TreeItem.ActualDurationStr = String(Attributes.ActualDuration) + " " + ActualDurationPresentation;
	EndIf;
	
	ActualStartDate = ?(ValueIsFilled(Attributes.ActualStartDate), Attributes.ActualStartDate, CurrentSessionDate());
	TreeItem.StartDelay = (ActualStartDate > Attributes.StartDate);
	
	ActualEndDate = ?(ValueIsFilled(Attributes.ActualEndDate), Attributes.ActualEndDate, CurrentSessionDate());
	TreeItem.EndDelay = (ActualEndDate > Attributes.EndDate);
	
EndProcedure

&AtServer
Procedure FillInTreeRowsFromProjectPhases(PhasesTree, ProjectPhases)
	
	ProjectPhasesData = ProjectManagement.GetProjectPhasesData(ProjectPhases);
	For Each ProjectPhaseData In ProjectPhasesData Do
		
		Index = -1;
		ProjectManagementClientServer.FindPhaseInTreeByRef(PhasesTree.GetItems(), ProjectPhaseData.Key, Index);
		If Index = -1 Then
			Continue;
		EndIf;
		
		TreeItem = PhasesTree.FindByID(Index);
		
		FillInTreeRowFromPhase(TreeItem, ProjectPhaseData.Value);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateModifiedRowsOfPhases(ModifiedPhasesArray)
	
	UpdatedPhases = New Array;
	
	For Each ModifiedPhase In ModifiedPhasesArray Do
		
		If UpdatedPhases.Find(ModifiedPhase) <> Undefined Then
			Continue;
		EndIf;
		
		UpdatedPhases.Add(ModifiedPhase);
		
	EndDo;
	
	FillInTreeRowsFromProjectPhases(PhaseTree, UpdatedPhases);
	
EndProcedure

&AtServerNoContext
Procedure LockRowForEdit(Ref, FormIdentifier)
	
	If ValueIsFilled(Ref) Then
		LockDataForEdit(Ref, , FormIdentifier);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure UnlockRowForEdit(Ref, FormIdentifier)
	
	If ValueIsFilled(Ref) Then
		UnlockDataForEdit(Ref, FormIdentifier);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdatePhaseTree()
	
	ExpandedPhasesList.Clear();
	ProjectManagementClient.GetExpandedPhasesArray(Items.PhaseTree, PhaseTree.GetItems(), ExpandedPhasesList);
	
	FillInPhaseTree();
	
	ProjectManagementClient.SetTreeItemsExpanded(Items.PhaseTree, PhaseTree, ExpandedPhasesList);
	ProjectManagementClient.SetCurrentPhaseInTreeByRef(Items.PhaseTree, PhaseTree, CurrentProjectPhase);
	
EndProcedure

&AtClient
Procedure UpdateSmallCard()
	
	If Not ShowProcessesTasks Then
		Return;
	EndIf;
	
	MainTasks.Clear();
	
	TitleTasks = NStr("en = 'Tasks:'; ru = 'Задачи:';pl = 'Zadania:';es_ES = 'Tareas:';es_CO = 'Tareas:';tr = 'Görevler:';it = 'Compiti:';de = 'Aufgaben:'");
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
	
	TaskArray = GetSmallCardData(CurrentData.Ref);
	
	For Each TaskItem In TaskArray Do
		NewRow = MainTasks.Add();
		FillPropertyValues(NewRow, TaskItem);
	EndDo;
	
	TasksCount = TaskArray.Count();
	If TasksCount > 0 Then
		TitleTasks = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Tasks (%1):'; ru = 'Задачи (%1):';pl = 'Zadania (%1):';es_ES = 'Tareas (%1):';es_CO = 'Tareas (%1):';tr = 'Görevler (%1):';it = 'Compiti (%1):';de = 'Aufgaben (%1):'"),
			TasksCount);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSmallCardData(ProjectPhase)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	PerformerTask.Performer AS Performer,
	|	PerformerTask.DueDate AS DueDate,
	|	PerformerTask.PerformerRole AS PerformerRole,
	|	PerformerTask.RoutePoint AS RoutePoint,
	|	PerformerTask.BusinessProcess AS BusinessProcess,
	|	CASE
	|		WHEN PerformerTask.DueDate <> DATETIME(1, 1, 1)
	|				AND PerformerTask.DueDate < &CurrentDate
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Expired,
	|	PerformerTask.Ref AS Ref,
	|	PerformerTask.Description AS Description
	|FROM
	|	Task.PerformerTask AS PerformerTask
	|WHERE
	|	PerformerTask.ProjectPhase = &ProjectPhase
	|	AND NOT PerformerTask.Executed
	|	AND NOT PerformerTask.DeletionMark
	|	AND PerformerTask.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Running)";
	
	Query.SetParameter("ProjectPhase", ProjectPhase);
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	Result = Query.Execute();
	
	Return GetTasksData(Result);
	
EndFunction

&AtServerNoContext
Function GetTasksData(QueryResult)
	
	TaskArray = New Array;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		TaskRow = New Structure(
			"Performer,
			|DueDate,
			|RoutePoint, 
			|Ref,
			|Expired,
			|BusinessProcess,
			|Description");
		
		If ValueIsFilled(Selection.Performer) Then
			PerformerStr = String(Selection.Performer);
		Else
			PerformerStr = String(Selection.PerformerRole);
		EndIf;
		
		TaskRow.Performer = PerformerStr;
		TaskRow.DueDate = Selection.DueDate;
		TaskRow.RoutePoint = Selection.RoutePoint;
		TaskRow.Ref = Selection.Ref;
		TaskRow.BusinessProcess = Selection.BusinessProcess;
		TaskRow.Expired = Selection.Expired;
		TaskRow.Description = Selection.Description;
		
		TaskArray.Add(TaskRow);
		
	EndDo;
	
	Return TaskArray;
	
EndFunction

&AtClientAtServerNoContext
Function GetDurationPresentation(DurationUnit)
	
	Return Lower(String(DurationUnit));
	
EndFunction

&AtServer
Procedure WriteProjectPhaseFromTreeRow(RowIndex, ModifiedPhasesArray = Undefined)
	
	TreeItem = PhaseTree.FindByID(RowIndex);
	
	If ValueIsFilled(TreeItem.Ref) Then
		
		ProjectPhaseObject = TreeItem.Ref.GetObject();
		
		If TreeItem.DataVersion <> TreeItem.Ref.DataVersion Then
			
			UnlockRowForEdit(ProjectPhaseObject.Ref, UUID);
			
			FillInTreeRowFromPhase(TreeItem, ProjectPhaseObject.Ref);
			
			Raise NStr("en = 'The data was changed by another user.'; ru = 'Данные изменены другим пользователем.';pl = 'Dane zostały zmienione przez innego użytkownika.';es_ES = 'Los datos se han cambiado por otro usuario.';es_CO = 'Los datos se han cambiado por otro usuario.';tr = 'Veri başka bir kullanıcı tarafından değiştirildi.';it = 'I dati sono stati modificati da un altro utente.';de = 'Die Daten wurden von einem anderen Benutzer geändert.'");
			
		EndIf;
		
	Else
		
		ProjectPhaseObject = Catalogs.ProjectPhases.CreateItem();
		
		CodeData = ProjectManagement.GetCodeWBSAndPhaseNumberInLevel(TreeItem.Owner, TreeItem.ParentPhase);
		
		ProjectPhaseObject.CodeWBS = CodeData.CodeWBS;
		ProjectPhaseObject.PhaseNumberInLevel = CodeData.PhaseNumberInLevel;
		
	EndIf;
	
	If ModifiedPhasesArray = Undefined Then
		ModifiedPhasesArray = New Array;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		ProjectPhaseObject.Description = TreeItem.Description;
		ProjectPhaseObject.Owner = TreeItem.Owner;
		ProjectPhaseObject.Parent = TreeItem.ParentPhase;
		ProjectPhaseObject.Status = TreeItem.Status;
		ProjectPhaseObject.PreviousPhase = TreeItem.PreviousPhase;
		ProjectPhaseObject.Executor = TreeItem.Executor;
		ProjectPhaseObject.AdditionalProperties.Insert("CheckPrevious", True);
		ProjectPhaseObject.Write();
		
		DataStructure = New Structure;
		DataStructure.Insert("ActualStartDate", TreeItem.ActualStartDate);
		DataStructure.Insert("ActualEndDate", TreeItem.ActualEndDate);
		DataStructure.Insert("ActualDuration", TreeItem.ActualDuration);
		DataStructure.Insert("ActualDurationUnit", TreeItem.ActualDurationUnit);
		
		DataStructure.Insert("StartDate", TreeItem.StartDate);
		DataStructure.Insert("EndDate", TreeItem.EndDate);
		DataStructure.Insert("Duration", TreeItem.Duration);
		DataStructure.Insert("DurationUnit", TreeItem.DurationUnit);
		
		ProjectManagement.WriteProjectPhaseTimelines(ProjectPhaseObject.Ref, DataStructure);
		
		TreeItem.Ref = ProjectPhaseObject.Ref;
		TreeItem.DataVersion = ProjectPhaseObject.DataVersion;
		
		UnlockRowForEdit(ProjectPhaseObject.Ref, UUID);
		
		ProjectManagement.CalculateProjectPlan(ProjectPhaseObject.Ref, ModifiedPhasesArray);
		ProjectManagement.UpdateParentsStatus(ProjectPhaseObject.Ref, ModifiedPhasesArray);
		
		If ValueIsFilled(ProjectPhaseObject.Parent)
			And ModifiedPhasesArray.Find(ProjectPhaseObject.Parent) = Undefined Then
			ModifiedPhasesArray.Add(ProjectPhaseObject.Parent);
		EndIf;
		
		UpdateModifiedRowsOfPhases(ModifiedPhasesArray);
		
		UserWorkHistory.Add(ProjectPhaseObject.Ref);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		UnlockRowForEdit(ProjectPhaseObject.Ref, UUID);
		
		ModifiedPhasesArray.Add(ProjectPhaseObject.Ref);
		UpdateModifiedRowsOfPhases(ModifiedPhasesArray);
		
		Raise;
		
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Function GetAvailabilityDataMovementCommands(PhaseTree, FormItems)
	
	PhaseTreeUp = True;
	PhaseTreeDown = True;
	PhaseTreeLevelUp = True;
	PhaseTreeLevelDown = True;
	
	SelectedRows = FormItems.PhaseTree.SelectedRows;
	SelectedRowsCount = SelectedRows.Count();
	
	For Each Row In SelectedRows Do
		
		CurrentRow = PhaseTree.FindByID(Row);
		ParentRow = CurrentRow.GetParent();
		
		PhaseTreeLevelUp = (PhaseTreeLevelUp
			And ParentRow <> Undefined
			And SelectedRowsCount = 1
			And Not CurrentRow.DeletionMark);
		
		If ParentRow = Undefined Then
			ParentRow = PhaseTree;
		EndIf;
		
		PhaseTreeLevelDown = (PhaseTreeLevelDown
			And ParentRow.GetItems().IndexOf(CurrentRow) > 0
			And SelectedRowsCount = 1
			And Not CurrentRow.DeletionMark);
		
		PhaseTreeUp = (PhaseTreeUp And ParentRow.GetItems().IndexOf(CurrentRow) > 0 And Not CurrentRow.DeletionMark);
		
		PhaseTreeDown = PhaseTreeDown
			And ParentRow.GetItems().IndexOf(CurrentRow) < ParentRow.GetItems().Count() - 1
			And Not CurrentRow.DeletionMark;
		
	EndDo;
	
	ReturnData = New Structure;
	ReturnData.Insert("PhaseTreeUp",		PhaseTreeUp);
	ReturnData.Insert("PhaseTreeDown",		PhaseTreeDown);
	ReturnData.Insert("PhaseTreeLevelUp",	PhaseTreeLevelUp);
	ReturnData.Insert("PhaseTreeLevelDown",	PhaseTreeLevelDown);
	
	Return ReturnData;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items)
	
	AvailabilityData = GetAvailabilityDataMovementCommands(PhaseTree, Items);
	
	Items.PhaseTreeUp.Enabled = AvailabilityData.PhaseTreeUp;
	Items.PhaseTreeContextMenuUp.Enabled = AvailabilityData.PhaseTreeUp;
	Items.PhaseTreeDown.Enabled = AvailabilityData.PhaseTreeDown;
	Items.PhaseTreeContextMenuDown.Enabled = AvailabilityData.PhaseTreeDown;
	
	Items.PhaseTreeLevelUp.Enabled = AvailabilityData.PhaseTreeLevelUp;
	Items.PhaseTreeContextMenuLevelUp.Enabled = AvailabilityData.PhaseTreeLevelUp;
	Items.PhaseTreeLevelDown.Enabled = AvailabilityData.PhaseTreeLevelDown;
	Items.PhaseTreeContextMenuLevelDown.Enabled = AvailabilityData.PhaseTreeLevelDown;
	
EndProcedure

&AtServer
Function SetDeletionMarkProjectPhases(SelectedRows, DeletionMark)
	
	For Each Row In SelectedRows Do
		
		ProjectPhaseRow = PhaseTree.FindByID(Row);
		If ProjectPhaseRow = Undefined Then
			Continue;
		EndIf;
		
		ProjectPhaseRef = ProjectPhaseRow.Ref;
		If ProjectPhaseRef.IsEmpty() Then
			Continue;
		EndIf;
		
		If DeletionMark And ProjectPhaseRow.Status = Enums.ProjectPhaseStatuses.InProgress Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot mark phase ""%1"" for deletion. Its status in In progress.'; ru = 'Не удалось пометить этап ""%1"" на удаление, поскольку его статус – В работе.';pl = 'Nie można zaznaczyć etapu ""%1"" do usunięcia. Ma on status W toku.';es_ES = 'No se ha podido marcar la fase ""%1"" para su eliminación. Su estado es En progreso.';es_CO = 'No se ha podido marcar la fase ""%1"" para su eliminación. Su estado es En progreso.';tr = '""%1"" evresi silinmek üzere işaretlenemez. Durumu İşlemde.';it = 'Impossibile contrassegnare fase ""%1"" per l''eliminazione. Il suo stato è In lavorazione.';de = 'Phase ""%1"" kann nicht zum Löschen markiert werden, da deren Status In Bearbeitung ist.'"),
				ProjectPhaseRef);
			CommonClientServer.MessageToUser(MessageText);
			
			Continue;
			
		EndIf;
		
		ProjectPhaseObject = ProjectPhaseRef.GetObject();
		ProjectPhaseObject.SetDeletionMark(DeletionMark);
		
		If ValueIsFilled(ProjectPhaseRow.ParentPhase) Then
			ProjectManagement.CalculateProjectPlan(ProjectPhaseRow.ParentPhase);
			ProjectManagement.UpdateParentsStatus(ProjectPhaseRow.ParentPhase);
		EndIf;
		
	EndDo;
	
	FillInPhaseTree();
	
EndFunction

&AtServer
Procedure FillInDataAboutNextPhases(NextPhasesArray, PhasesArray)
	
	For Each Item In PhasesArray Do
		
		NextPhasesOfPhase = ProjectManagement.GetAllNextPhases(Item).UnloadColumn("Ref");
		For Each NextPhaseItem In NextPhasesOfPhase Do
			If NextPhasesArray.Find(NextPhaseItem) = Undefined Then
				NextPhasesArray.Add(NextPhaseItem);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetAvailabilityOfPhaseTreeFields(Mode)
	
	If Mode = "InList" Then 
		Items.PhaseTreeEditInList.Check = True;
		Items.PhaseTreeEditInCard.Check = False;
	Else
		Items.PhaseTreeEditInList.Check = False;
		Items.PhaseTreeEditInCard.Check = True;
	EndIf;
	
EndProcedure

&AtClient
Function GetNumberPart(Val String)
	
	String = TrimAll(String);
	If IsBlankString(String) Then
		Return "0";
	EndIf;
	
	NumberPart = "";
	ValidCharacters = "0123456789., ";
	
	For Indx = 1 По StrLen(String) Do
		
		Character = Mid(String, Indx, 1);
		If Find(ValidCharacters, Character) > 0 Then
			NumberPart = NumberPart + Character;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	NumberPart = StrReplace(NumberPart, " ", "");
	
	Return NumberPart;
	
EndFunction

&AtServer
Function ConnectPhasesServer()
	
	Result = False;
	
	CurrentRow = Items.PhaseTree.CurrentRow;
	NextPhase = PhaseTree.FindByID(CurrentRow).Ref;
	
	For Each Row In Items.PhaseTree.SelectedRows Do
		
		PreviousPhase = PhaseTree.FindByID(Row).Ref;
		If PreviousPhase <> NextPhase And NextPhase.PreviousPhase <> PreviousPhase Then
			
			BeginTransaction();
			
			Try
				
				NextPhaseObject = NextPhase.GetObject();
				NextPhaseObject.PreviousPhase = PreviousPhase;
				NextPhaseObject.AdditionalProperties.Insert("CheckPrevious", True);
				NextPhaseObject.Write();
				
				ModifiedPhasesArray = New Array;
				ProjectManagement.CalculateProjectPlan(NextPhase, ModifiedPhasesArray);
				UpdateModifiedRowsOfPhases(ModifiedPhasesArray);
				
				CommitTransaction();
				
				Result = True;
				
			Except
				
				RollbackTransaction();
				Raise;
				
			EndTry;
			
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure LevelDownServer(Ref, Parent)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProjectPhases.Ref AS Ref
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|WHERE
	|	ProjectPhases.Parent = &Parent
	|	AND ProjectPhases.Owner = &Project
	|	AND NOT ProjectPhases.DeletionMark
	|	AND ProjectPhases.PhaseNumberInLevel = &NumberInLevel - 1";
	
	Query.SetParameter("Parent", Parent);
	Query.SetParameter("NumberInLevel", Ref.PhaseNumberInLevel);
	Query.SetParameter("Project", Ref.Owner);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select();
	If Selection.Next() Then
		
		BeginTransaction();
		
		Try
			
			PhaseObject = Ref.GetObject();
			PhaseParent = PhaseObject.Parent;
			
			PhaseObject.Parent = Selection.Ref;
			PhaseObject.PhaseNumberInLevel = ProjectManagement.GetMaxPhaseNumberInLevel(Ref.Owner, PhaseObject.Parent) + 1;
			PhaseObject.AdditionalProperties.Insert("CheckPrevious", True);
			PhaseObject.Write();
			
			ProjectManagement.FillInProjectPhasesCodeWBS(Ref.Owner);
			
			If ValueIsFilled(PhaseParent) Then
				ProjectManagement.CalculateProjectPlan(PhaseParent);
				ProjectManagement.UpdateParentsStatus(PhaseParent);
			EndIf;
			
			If ValueIsFilled(PhaseObject.Parent) Then
				ProjectManagement.CalculateProjectPlan(PhaseObject.Parent);
				ProjectManagement.UpdateParentsStatus(PhaseObject.Parent);
			EndIf;
			
			FillInPhaseTree();
			
			ExpandedPhasesList.Add(PhaseObject.Parent);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			Raise;
			
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure LevelUpServer(Ref, Parent)
	
	ParentLevelPhasesArray = ProjectManagement.GetPhasesSameLevelPhases(Ref.Owner, Parent);
	
	ItemsCount = ParentLevelPhasesArray.Count();
	
	For Counter = 0 To ItemsCount - 1 Do
		Index = ItemsCount - Counter - 1;
		Phase = ParentLevelPhasesArray[Index];
		If Phase.PhaseNumberInLevel > Parent.PhaseNumberInLevel Then
			PhaseObject = Phase.GetObject();
			PhaseObject.PhaseNumberInLevel = PhaseObject.PhaseNumberInLevel + 1;
		EndIf;
	EndDo;
	
	BeginTransaction();
	
	Try
		
		PhaseObject = Ref.GetObject();
		PhaseParent = PhaseObject.Parent;
		
		PhaseObject.Parent = Parent.Parent;
		PhaseObject.PhaseNumberInLevel = Parent.PhaseNumberInLevel + 1;
		PhaseObject.AdditionalProperties.Insert("CheckPrevious", True);
		PhaseObject.Write();
		
		ProjectManagement.FillInProjectPhasesCodeWBS(Ref.Owner);
		
		If ValueIsFilled(PhaseParent) Then
			ProjectManagement.CalculateProjectPlan(PhaseParent);
			ProjectManagement.UpdateParentsStatus(PhaseParent);
		EndIf;
		
		If ValueIsFilled(PhaseObject.Parent) Then
			ProjectManagement.CalculateProjectPlan(PhaseObject.Parent);
			ProjectManagement.UpdateParentsStatus(PhaseObject.Parent);
		EndIf;
		
		FillInPhaseTree();
		
		ExpandedPhasesList.Add(PhaseObject.Parent);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

&AtServer
Procedure UpServer()
	
	SetPrivilegedMode(True);
	
	RefArray = New Array;
	
	For Each SelectedRow In Items.PhaseTree.SelectedRows Do
		
		Ref = PhaseTree.FindByID(SelectedRow).Ref;
		
		Index = Undefined;
		For Each Item In RefArray Do
			If Item.PhaseNumberInLevel > Ref.PhaseNumberInLevel Then
				Index = RefArray.Find(Item);
				Break;
			EndIf;
		EndDo;
		
		If Index = Undefined Then
			RefArray.Add(Ref);
		Else
			RefArray.Insert(Index, Ref);
		EndIf;
	EndDo;
	
	For Each Ref In RefArray Do
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	ProjectPhases.Ref AS Ref
		|FROM
		|	Catalog.ProjectPhases AS ProjectPhases
		|WHERE
		|	ProjectPhases.Owner = &Owner
		|	AND ProjectPhases.Parent = &Parent
		|	AND NOT ProjectPhases.DeletionMark
		|	AND ProjectPhases.PhaseNumberInLevel = &PhaseNumberInLevel";
		
		Query.SetParameter("Owner", Ref.Owner);
		Query.SetParameter("Parent", Ref.Parent);
		Query.SetParameter("PhaseNumberInLevel", Ref.PhaseNumberInLevel - 1);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Id = -1;
			ProjectManagementClientServer.FindPhaseInTreeByRef(PhaseTree.GetItems(), Ref, Id);
			
			CurrentPhaseRow = PhaseTree.FindByID(Id);
			ParentPhaseRow = CurrentPhaseRow.GetParent();
			
			If ParentPhaseRow = Undefined Then
				ParentPhaseRow = PhaseTree;
			EndIf;
			
			CurrentPhaseIndex = ParentPhaseRow.GetItems().IndexOf(CurrentPhaseRow);
			ParentPhaseRow.GetItems().Move(CurrentPhaseIndex, -1);
			
			CurrentPhaseObject = Ref.GetObject();
			PreviousPhaseObject = Selection.Ref.GetObject();
			
			Buffer = CurrentPhaseObject.PhaseNumberInLevel;
			CurrentPhaseObject.PhaseNumberInLevel = PreviousPhaseObject.PhaseNumberInLevel;
			PreviousPhaseObject.PhaseNumberInLevel = Buffer;
			
			BufferWBS = CurrentPhaseObject.CodeWBS;
			CurrentPhaseObject.CodeWBS = PreviousPhaseObject.CodeWBS;
			PreviousPhaseObject.CodeWBS = BufferWBS;
			
			If CurrentPhaseObject.PreviousPhase = PreviousPhaseObject.Ref Then
				
				CurrentPhaseObject.PreviousPhase = PreviousPhaseObject.PreviousPhase;
				PreviousPhaseObject.PreviousPhase = CurrentPhaseObject.Ref;
				
			EndIf;
			
			CurrentPhaseObject.Write();
			PreviousPhaseObject.Write();
			
			ChangedPhases = New Array;
			ChangedPhases.Add(CurrentPhaseObject.Ref);
			ChangedPhases.Add(PreviousPhaseObject.Ref);
			
			ProjectManagement.FillInCodeWBSOfSubordinatePhases(CurrentPhaseObject.Ref, ChangedPhases);
			ProjectManagement.FillInCodeWBSOfSubordinatePhases(PreviousPhaseObject.Ref, ChangedPhases);
			
			FillInDataAboutNextPhases(ChangedPhases, ChangedPhases);
			UpdateModifiedRowsOfPhases(ChangedPhases);
			
			ExpandedPhasesList.Add(CurrentProjectPhase.Parent);
			
		EndIf;
		
	EndDo;
	
	If RefArray.Count() > 0 Then 
		ProjectManagement.FillInProjectPhasesOrder(Project);
	EndIf;
	
	SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items);
	
EndProcedure

&AtServer
Procedure DownServer()
	
	RefArray = New Array;
	
	For Each SelectedRow In Items.PhaseTree.SelectedRows Do
		
		Ref = PhaseTree.FindByID(SelectedRow).Ref;
		
		Index = Undefined;
		For Each Item In RefArray Do
			If Item.PhaseNumberInLevel < Ref.PhaseNumberInLevel Then
				Index = RefArray.Find(Item);
				Break;
			EndIf;
		EndDo;
		
		If Index = Undefined Then
			RefArray.Add(Ref);
		Else
			RefArray.Insert(Index, Ref);
		EndIf;
	EndDo;
	
	For Each Ref In RefArray Do
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	ProjectPhases.Ref AS Ref
		|FROM
		|	Catalog.ProjectPhases AS ProjectPhases
		|WHERE
		|	ProjectPhases.Owner = &Owner
		|	AND ProjectPhases.Parent = &Parent
		|	AND NOT ProjectPhases.DeletionMark
		|	AND ProjectPhases.PhaseNumberInLevel = &PhaseNumberInLevel";
		
		Query.SetParameter("Owner", Ref.Owner);
		Query.SetParameter("Parent", Ref.Parent);
		Query.SetParameter("PhaseNumberInLevel", Ref.PhaseNumberInLevel + 1);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Id = -1;
			ProjectManagementClientServer.FindPhaseInTreeByRef(PhaseTree.GetItems(), Ref, Id);
			CurrentPhaseRow = PhaseTree.FindByID(Id);
			ParentPhaseRow = CurrentPhaseRow.GetParent();
			
			If ParentPhaseRow = Undefined Then
				ParentPhaseRow = PhaseTree;
			EndIf;
			
			CurrentPhaseIndex = ParentPhaseRow.GetItems().IndexOf(CurrentPhaseRow);
			ParentPhaseRow.GetItems().Move(CurrentPhaseIndex, 1);
			
			CurrentPhaseObject = Ref.GetObject();
			NextPhaseObject = Selection.Ref.GetObject();
			
			Buffer = CurrentPhaseObject.PhaseNumberInLevel;
			CurrentPhaseObject.PhaseNumberInLevel = NextPhaseObject.PhaseNumberInLevel;
			NextPhaseObject.PhaseNumberInLevel = Buffer;
			
			BufferWBS = CurrentPhaseObject.CodeWBS;
			CurrentPhaseObject.CodeWBS = NextPhaseObject.CodeWBS;
			NextPhaseObject.CodeWBS = BufferWBS;
			
			If NextPhaseObject.PreviousPhase = CurrentPhaseObject.Ref Then
				
				NextPhaseObject.PreviousPhase = CurrentPhaseObject.PreviousPhase;
				CurrentPhaseObject.PreviousPhase = NextPhaseObject.Ref;
				
			EndIf;
			
			CurrentPhaseObject.Write();
			NextPhaseObject.Write();
			
			ChangedPhases = New Array;
			ChangedPhases.Add(CurrentPhaseObject.Ref);
			ChangedPhases.Add(NextPhaseObject.Ref);
			
			ProjectManagement.FillInCodeWBSOfSubordinatePhases(CurrentPhaseObject.Ref, ChangedPhases);
			ProjectManagement.FillInCodeWBSOfSubordinatePhases(NextPhaseObject.Ref, ChangedPhases);
			
			FillInDataAboutNextPhases(ChangedPhases, ChangedPhases);
			UpdateModifiedRowsOfPhases(ChangedPhases);
			
			ExpandedPhasesList.Add(CurrentProjectPhase.Parent);
			
		EndIf;
		
	EndDo;
	
	If RefArray.Count() > 0 Then
		ProjectManagement.FillInProjectPhasesOrder(Project);
	EndIf;
	
	SetAvailabilityMovementCommands(CurrentProjectPhase, PhaseTree, Items);
	
EndProcedure

&AtServer
Procedure PhaseTreeDragServer(SourceRef, ReceiverRef)
	
	BeginTransaction();
	
	Try
		
		SourceObject = SourceRef.GetObject();
		SourceOldParent = SourceObject.Parent;
		
		SourceNewParent = ReceiverRef;
		SourceObject.Parent = SourceNewParent;
		
		SourceObject.PhaseNumberInLevel = ProjectManagement.GetMaxPhaseNumberInLevel(SourceObject.Owner, SourceObject.Parent) + 1;
		SourceObject.AdditionalProperties.Insert("CheckPrevious", True);
		SourceObject.Write();
		
		If ValueIsFilled(SourceOldParent) Then 
			ProjectManagement.CalculateProjectPlan(SourceOldParent);
			ProjectManagement.UpdateParentsStatus(SourceOldParent);
		EndIf;
		
		ProjectManagement.CalculateProjectPlan(SourceRef);
		ProjectManagement.UpdateParentsStatus(SourceRef);
		
		ProjectManagement.FillInProjectPhasesCodeWBS(SourceObject.Owner);
		
		FillInPhaseTree();
		
		ExpandedPhasesList.Add(ReceiverRef);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ShowHideClearButton(Field, Value)
	
	If ValueIsFilled(Value) And Value <> "All" Then
		
		Field.ClearButton = True;
		
		#If Client Then
			Field.BackColor = CommonClient.StyleColor("MasterFieldBackground");
		#Else
			Field.BackColor = StyleColors["MasterFieldBackground"];
		#EndIf
		
	Else
		Field.ClearButton = False;
		Field.BackColor = New Color();
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowLevel(Level, Val CurrentLevel = 0, ParentRow = Undefined)
	
	If ParentRow = Undefined Then
		ParentRow = PhaseTree;
	EndIf;
	
	CurrentLevel = CurrentLevel + 1;
	
	If Level <= CurrentLevel Then
		For Each Row In ParentRow.GetItems() Do
			Items.PhaseTree.Collapse(Row.GetID());
		EndDo;
	Else
		For Each Row In ParentRow.GetItems() Do
			Items.PhaseTree.Expand(Row.GetID());
			ShowLevel(Level, CurrentLevel, Row);
		EndDo;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GenerateUserSelectionData(Text)
	
	Return Users.GenerateUserSelectionData(Text, False, False);
	
EndFunction

&AtClient
Procedure CheckProjectPhaseNewStatusEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ClearMessages();
		ProjectManagement.CompleteProjectPhaseTasks(AdditionalParameters.CurrentData.Ref);
		UpdateSmallCard();
	Else
		AdditionalParameters.CurrentData.Status = AdditionalParameters.PrevStatus;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessActualEndDateChange(CurrentData = Undefined)
	
	If CurrentData = Undefined Then
		CurrentData = Items.PhaseTree.CurrentData;
	EndIf;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.ActualEndDate)
		And CurrentData.ActualEndDate = BegOfDay(CurrentData.ActualEndDate)
		And ProjectAttributes.UseWorkSchedule Then
		
		WorkSchedule = ?(ValueIsFilled(CurrentData.WorkSchedule),
		CurrentData.WorkSchedule,
		ProjectAttributes.WorkSchedule);
		
		CurrentData.ActualEndDate = WorkSchedulesDrive.GetLastWorkingTimeOfDay(WorkSchedule, CurrentData.ActualEndDate);
		
	EndIf;
	
	If ValueIsFilled(CurrentData.ActualEndDate) And ValueIsFilled(CurrentData.ActualStartDate) Then
		
		ProjectPhaseStructure = New Structure;
		ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
		ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
		
		CurrentData.ActualDuration = ProjectManagement.CalculatePeriodDuration(ProjectPhaseStructure,
			CurrentData.ActualStartDate,
			CurrentData.ActualEndDate,
			CurrentData.ActualDurationUnit);
		
		DurationPresentation = GetDurationPresentation(CurrentData.ActualDurationUnit);
		CurrentData.ActualDurationStr = String(CurrentData.ActualDuration) + " " + DurationPresentation;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessActualStartDateChange(CurrentData = Undefined)
	
	If CurrentData = Undefined Then
		CurrentData = Items.PhaseTree.CurrentData;
	EndIf;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.ActualStartDate)
		And CurrentData.ActualStartDate = BegOfDay(CurrentData.ActualStartDate)
		And ProjectAttributes.UseWorkSchedule Then
		
		WorkSchedule = ?(ValueIsFilled(CurrentData.WorkSchedule),
			CurrentData.WorkSchedule,
			ProjectAttributes.WorkSchedule);
		
		CurrentData.ActualStartDate = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(WorkSchedule, CurrentData.ActualStartDate);
		
	EndIf;
	
	If ValueIsFilled(CurrentData.ActualStartDate) And ValueIsFilled(CurrentData.ActualDuration) Then
		
		ProjectPhaseStructure = New Structure;
		ProjectPhaseStructure.Insert("Owner", CurrentData.Owner);
		ProjectPhaseStructure.Insert("WorkSchedule", CurrentData.WorkSchedule);
		
		CurrentData.ActualEndDate = ProjectManagement.CalculatePeriodEnd(ProjectPhaseStructure,
			CurrentData.ActualStartDate,
			CurrentData.ActualDuration,
			CurrentData.ActualDurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnableActualAttributes(CurrentData = Undefined)
	
	If CurrentData = Undefined Then
		CurrentData = Items.PhaseTree.CurrentData;
	EndIf;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.ActualStartDate.ReadOnly = CurrentData.SummaryPhase
		Or CurrentData.Status <> PredefinedValue("Enum.ProjectPhaseStatuses.InProgress");
	Items.ActualEndDate.ReadOnly = CurrentData.SummaryPhase
		Or CurrentData.Status <> PredefinedValue("Enum.ProjectPhaseStatuses.Completed");
	Items.ActualDurationStr.ReadOnly = CurrentData.SummaryPhase
		Or CurrentData.Status <> PredefinedValue("Enum.ProjectPhaseStatuses.Completed");
	
EndProcedure

&AtClient
Procedure SetEnableByStatus()
	
	CurrentData = Items.PhaseTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CreateTaskEnabled = (CurrentData.Status = PredefinedValue("Enum.ProjectPhaseStatuses.InProgress")
		And Not CurrentData.DeletionMark);
	
	Items.CreateTask.Enabled = CreateTaskEnabled;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceOnCreate()
	
	// 1
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.DeletionMark");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font("MS Shell Dlg", 8, True, False, False, True, 100));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PhaseTree");
	FieldAppearance.Use = True;
	
	// 2
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.DeletionMark");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font("MS Shell Dlg", 8, True, False, False, False, 100));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PhaseTree");
	FieldAppearance.Use = True;
	
	// 3
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.DeletionMark");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font("MS Shell Dlg", 8, False, False, False, True, 100));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PhaseTree");
	FieldAppearance.Use = True;
	
	// 4
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ViewMode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Contains;
	DataFilterItem.RightValue		= "ForExecution";
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.ActualStartDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.StartDelay");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("StartDate");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Status");
	FieldAppearance.Use = True;
	
	// 5
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ViewMode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Contains;
	DataFilterItem.RightValue		= "ExecutionControl";
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.ActualEndDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.EndDelay");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.ActualStartDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Filled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EndDate");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Status");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ActualEndDate");
	FieldAppearance.Use = True;
	
	// 6
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.OrGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ViewMode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Contains;
	DataFilterItem.RightValue		= "ExecutionControl";
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ViewMode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Contains;
	DataFilterItem.RightValue		= "ForExecution";
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.ActualEndDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Filled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EndDate");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Status");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ActualEndDate");
	FieldAppearance.Use = True;
	
	// 7
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ViewMode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Contains;
	DataFilterItem.RightValue		= "ExecutionControl";
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.ActualEndDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.EndDelay");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.ActualStartDate");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Filled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("PhaseTree.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", WebColors.Green);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EndDate");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Status");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ActualEndDate");
	FieldAppearance.Use = True;
	
	// 8
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("MainTasks.Expired");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("MainTasksDueDate");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion