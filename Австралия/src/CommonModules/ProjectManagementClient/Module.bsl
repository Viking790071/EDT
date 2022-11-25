
#Region Internal

Function SelectProjectProjectPhase(Item, Project, ProjectPhase) Export 
	
	FormParameters = New Structure;
	FormParameters.Insert("Project", Project);
	FormParameters.Insert("ProjectPhase", ProjectPhase);
	
	OpenForm("CommonForm.SelectProjectPhase", FormParameters, Item);
	
EndFunction

Procedure GetExpandedPhasesArray(TreeItem, LevelRowsArray, ExpandedPhasesList) Export
	
	For Each LevelRow In LevelRowsArray Do
		PhaseID = LevelRow.GetID();
		If TreeItem.Expanded(PhaseID) <> Undefined And TreeItem.Expanded(PhaseID) Then
			ExpandedPhasesList.Add(LevelRow.Ref);
		EndIf;
		GetExpandedPhasesArray(TreeItem, LevelRow.GetItems(), ExpandedPhasesList);
	EndDo;
	
EndProcedure

Procedure SetTreeItemsExpanded(TreeItem, TreeAttribute, PhasesListToExpand) Export
	
	If PhasesListToExpand <> Undefined Then
		For Each ListItem In PhasesListToExpand Do
			Index = -1;
			ProjectManagementClientServer.FindPhaseInTreeByRef(TreeAttribute.GetItems(), ListItem.Value, Index);
			If Index > -1 Then
				If TreeAttribute.FindByID(Index).GetItems().Count() > 0 Then
					TreeItem.Expand(TreeAttribute.FindByID(Index).GetID(), False);
				Else
					If TreeAttribute.FindByID(Index).GetParent() <> Undefined Then
						TreeItem.Expand(TreeAttribute.FindByID(Index).GetParent().GetID(), False);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Procedure SetCurrentPhaseInTreeByRef(TreeItem, TreeAttribute, CurrentPhase) Export
	
	If CurrentPhase <> Undefined And Not CurrentPhase.IsEmpty() Then
		Index = -1;
		ProjectManagementClientServer.FindPhaseInTreeByRef(TreeAttribute.GetItems(), CurrentPhase, Index);
		If Index > -1 Then
			TreeItem.CurrentRow = Index;
		EndIf;
	EndIf;
	
EndProcedure

Procedure SetSelectedPhaseInTreeByRef(TreeItem, TreeAttribute, CurrentPhase) Export
	
	If CurrentPhase <> Undefined And Not CurrentPhase.IsEmpty() Then
		Index = -1;
		ProjectManagementClientServer.FindPhaseInTreeByRef(TreeAttribute.GetItems(), CurrentPhase, Index);
		If Index > -1 Then
			TreeItem.SelectedRows.Add(Index);
		EndIf;
	EndIf;
	
EndProcedure

#Region Template

Procedure LoadProjectFromTemplate(Project) Export
	
	AdditionalParameters = New Structure("Project", Project);
	
	If ProjectManagement.IsProjectPhasesExist(Project) Then
		
		NotifyDescription = New NotifyDescription("LoadProjectFromTemplateFragment",
			ThisObject,
			AdditionalParameters);
		
		ShowQueryBox(NotifyDescription,
			NStr("en = 'The existing project data will cleared. New data will be imported from the template. Continue?'; ru = 'Существующие данные проекта будут очищены. Новые данные будут загружены из шаблона. Продолжить?';pl = 'Dane istniejącego projektu zostaną wyczyszczone. Nowe dane zostaną importowane z szablonu. Kontynuować?';es_ES = 'Los datos existentes del proyecto se borrarán. Los nuevos datos se importarán desde la plantilla. ¿Continuar?';es_CO = 'Los datos existentes del proyecto se borrarán. Los nuevos datos se importarán desde la plantilla. ¿Continuar?';tr = 'Mevcut proje verileri silinecek. Yeni veriler şablondan aktarılacak. Devam edilsin mi?';it = 'I dati esistenti del progetto verranno cancellati. Verranno importati nuovi dati dal modello. Continuare?';de = 'Die vorhandenen Projektdaten werden gelöscht. Neue Daten werden aus der Vorlage importiert. Fortfahren?'"),
			QuestionDialogMode.YesNo);
		
	Else
		
		LoadProjectFromTemplateFragment(DialogReturnCode.Yes, AdditionalParameters);
		
	EndIf;
	
EndProcedure

Procedure LoadProjectFromTemplateFragment(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		NotifyDescription = New NotifyDescription("LoadProjectFromTemplateEnd",
			ThisObject,
			AdditionalParameters);
		
		OpenForm("Catalog.ProjectTemplates.Form.SelectTemplateForm",
			,
			ThisObject,
			True,
			,
			,
			NotifyDescription,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

Procedure LoadProjectFromTemplateEnd(Result, AdditionalParameters) Export
	
	Project = AdditionalParameters.Project;
	
	If TypeOf(Result) = Type("Structure") Then
		ProjectTemplate = Result.TemplateRef;
		CalculationStartDate = Result.CalculationStartDate;
	Else
		ProjectTemplate = Result;
		CalculationStartDate = Date(1, 1, 1);
	EndIf;
	
	If TypeOf(ProjectTemplate) = Type("CatalogRef.ProjectTemplates")
		And ValueIsFilled(ProjectTemplate)
		And TypeOf(Project) = Type("CatalogRef.Projects")
		And ValueIsFilled(Project) Then
		
		If ProjectManagement.LoadProjectFromTemplate(ProjectTemplate, Project, CalculationStartDate) Then
			
			NotifyChanged(Project);
			Notify("Change_Project", New Structure("Project", Project), ThisObject);
			
			CommonClientServer.MessageToUser(NStr("en = 'The project data were imported from the template.'; ru = 'Данные проекта загружены из шаблона.';pl = 'Dane projektu zostały importowane z szablonu.';es_ES = 'Los datos del proyecto se importaron desde la plantilla.';es_CO = 'Los datos del proyecto se importaron desde la plantilla.';tr = 'Proje verileri şablondan içe aktarılacak.';it = 'I dati del progetto sono stati importati dal modello.';de = 'Die Projektdaten wurden aus der Vorlage importiert.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion