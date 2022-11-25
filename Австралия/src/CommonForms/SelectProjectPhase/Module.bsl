#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Parameters.Project) Then
		
		CurrentProject = Parameters.Project;
		Items.Projects.CurrentRow = CurrentProject;
		
		CommonClientServer.SetFilterItem(ProjectPhases.Filter, "Owner", CurrentProject);
		
		If ValueIsFilled(Parameters.ProjectPhase) Then
			Items.ProjectPhases.CurrentRow = Parameters.ProjectPhase;
		EndIf;
		
	EndIf;
	
	SelectOnlyProjectPhase = Parameters.SelectOnlyProjectPhase;
	If SelectOnlyProjectPhase Then 
		ThisObject.Title = NStr("en = 'Project phase selection'; ru = 'Выбор этапа проекта';pl = 'Wybór etapu projektu';es_ES = 'Selección de la fase del proyecto';es_CO = 'Selección de la fase del proyecto';tr = 'Proje evresi seçimi';it = 'Selezione fase progetto';de = 'Auswahl von Projektphasen'");
	EndIf;
	
	CurrentUser = UsersClientServer.CurrentUser();
	Projects.Parameters.SetParameterValue("CurrentUser", CurrentUser);
	
	If ProjectManagement.HaveNoOwnProjects(CurrentUser) Then
		OnlyMyProjects = False;
	Else
		OnlyMyProjects = True;
	EndIf;
	
	SwitchFilterByProject();
	
	ShowMarkedToDelete = False;
	ShowDeleted();
	
	SetConditionalAppearanceOnCreate();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ShowMarkedToDelete = Settings["ShowMarkedToDelete"];
	ShowDeleted();
	
	OnlyMyProjects = Settings["OnlyMyProjects"];
	SwitchFilterByProject();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnlyMyProjectsOnChange(Item)
	
	SwitchFilterByProject();
	
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)

	If ValueIsFilled(SearchString) Then
		
		SearchString = TrimAll(SearchString);
		
		If StrLen(SearchString) < 3 And SearchString <> "*" And SearchString <> "**" Then
			CurrentItem = Items.SearchString;
			Activate();
			ShowMessageBox(, NStr("en = 'You should enter at least 3 characters.'; ru = 'Введите не менее 3 символов.';pl = 'Trzeba wprowadzić co najmniej 3 znaki.';es_ES = 'Debe introducir al menos 3 caracteres.';es_CO = 'Debe introducir al menos 3 caracteres.';tr = 'En az 3 karakter girmelisiniz.';it = 'Bisogna digitare almeno 3 caratteri.';de = 'Sie müssen zumindest 3 Zeichen eingeben.'"));
			Return;
		EndIf;
		
		EmptySearchResult = False;
		
		FindProjectsAndProjectPhases();
		EmptySearchResult = ProjectTree.GetItems().Count() = 0;
		
		If EmptySearchResult Then
			CurrentItem = Items.SearchString;
			SetVisibilityOfProjectSearchResult(False);
			ShowMessageBox(, NStr("en = 'Nothing was found for your search.'; ru = 'По вашему запросу ничего не найдено.';pl = 'Nie znaleziono nic dla twojego wyszukiwania.';es_ES = 'No se ha encontrado nada relacionado con su búsqueda.';es_CO = 'No se ha encontrado nada relacionado con su búsqueda.';tr = 'Aramanız için hiçbir şey bulunamadı.';it = 'La ricerca non ha prodotto risultati.';de = 'Für Ihre Suchanfrage wurde nichts gefunden.'"));
		Else
			CurrentItem = Items.ProjectTree;
			SetVisibilityOfProjectSearchResult(True);
			ExpandProjectTree();
		EndIf;
		
		SearchEnabled = True;
		
	Else
		If SearchEnabled Then
			ClearSearch();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchStringClearing(Item, StandardProcessing)
	
	SearchString = Undefined;
	ClearSearch();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProjects

&AtClient
Procedure ProjectsOnActivateRow(Item)
	
	If FirstActivate = Undefined Or FirstActivate Then
		FirstActivate = False;
		Return;
	EndIf;
	
	CurrentData = Items.Projects.CurrentData;
	If CurrentData = Undefined Then
		CurrentProject = Undefined;
		CommonClientServer.SetFilterItem(ProjectPhases.Filter, "Owner", CurrentProject);
		Return;
	EndIf;
	
	AttachIdleHandler("WaitProcessingProject", 0.2, True);
	
EndProcedure

&AtClient
Procedure ProjectsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	If SelectOnlyProjectPhase Then
		Return;
	EndIf;
	
	CurrentData = Items.Projects.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SelectedValue = New Structure("Project, ProjectPhase, ExistProjectPhases",
		CurrentData.Ref,
		Undefined,
		CurrentData.ExistProjectPhases);
	
	NotifyChoice(SelectedValue);
	Notify("ProjectOrProjectPhaseSelected", SelectedValue);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProjectTree

&AtClient
Procedure ProjectTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.ProjectTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If SelectOnlyProjectPhase Then
		
		If Not CurrentData.ЭтоЗадача Then
			Return;
		EndIf;
		
		SelectedValue = CurrentData.Ref;
		
	Else
		
		SelectedValue = New Structure("Project, ProjectPhase, ExistProjectPhases",
			CurrentData.Owner, 
			CurrentData.Ref,
			True);
		
	EndIf;
	
	NotifyChoice(SelectedValue);
	Notify("ProjectOrProjectPhaseSelected", SelectedValue);
	
EndProcedure

&AtClient
Procedure ProjectTreeBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	Return;
	
EndProcedure

&AtClient
Procedure ProjectTreeBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	CurrentData = Items.ProjectTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.Ref) Then
		
		FormParameter = New Structure("Key", CurrentData.Ref);
		
		If CurrentData.ЭтоЗадача Then
			OpenForm("Catalog.ProjectPhases.ObjectForm", FormParameter);
		Else
			OpenForm("Catalog.Projects.ObjectForm", FormParameter);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProjectTreeBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProjectPhases

&AtClient
Procedure ProjectPhasesValueChoice(Item, Value, StandardProcessing)
	
	CurrentData = Items.ProjectPhases.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If SelectOnlyProjectPhase Then
		SelectedValue = CurrentData.Ref;
	Else
		SelectedValue = New Structure("Project, ProjectPhase, ExistProjectPhases",
			CurrentData.Owner, 
			CurrentData.Ref,
			True);
	EndIf;
	
	NotifyChoice(SelectedValue);
	Notify("ProjectOrProjectPhaseSelected", SelectedValue);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	If SearchEnabled Then
		
		CurrentData = Items.ProjectTree.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		If SelectOnlyProjectPhase Then
			
			If Not CurrentData.IsPhase Then
				Return;
			EndIf;
			
			SelectedValue = CurrentData.Ref;
			
		Else
			SelectedValue = New Structure("Project, ProjectPhase, ExistProjectPhases",
				CurrentData.Owner, 
				CurrentData.Ref,
				True);
		EndIf;
		
		NotifyChoice(SelectedValue);
		Notify("ProjectOrProjectPhaseSelected", SelectedValue);
		
	ElsIf SelectOnlyProjectPhase Or Items.ProjectPhases.CurrentRow <> Undefined Then
		
		SelectPhase();
		
	ElsIf Items.Projects.CurrentRow <> Undefined Then
		
		SelectProject();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowMarkedToDelete(Command)
	
	ShowMarkedToDelete = Not ShowMarkedToDelete;
	
	ShowDeleted();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectProject()
	
	CurrentData = Items.Projects.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SelectedValue = New Structure("Project, ProjectPhase, ExistProjectPhases",
		CurrentData.Ref,
		Undefined,
		CurrentData.ExistProjectPhases);
	
	NotifyChoice(SelectedValue);
	Notify("ProjectOrProjectPhaseSelected", SelectedValue);
	
EndProcedure

&AtClient
Procedure SelectPhase()
	
	CurrentData = Items.ProjectPhases.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	If SelectOnlyProjectPhase Then 
		SelectedValue = CurrentData.Ref;
	Else
		SelectedValue = New Structure("Project, ProjectPhase, ExistProjectPhases",
			CurrentData.Owner,
			CurrentData.Ref,
			True);
	EndIf;
	
	NotifyChoice(SelectedValue);
	Notify("ProjectOrProjectPhaseSelected", SelectedValue);
	
EndProcedure

&AtClient
Procedure WaitProcessingProject()
	
	If Items.Projects.CurrentRow <> CurrentProject Then
		
		CurrentProject = Items.Projects.CurrentRow;
		
		CommonClientServer.SetFilterItem(ProjectPhases.Filter, "Owner", CurrentProject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowDeleted()
	
	If ShowMarkedToDelete Then
		CommonClientServer.DeleteDynamicListFilterGroupItems(Projects, "DeletionMark");
		CommonClientServer.DeleteDynamicListFilterGroupItems(ProjectPhases, "DeletionMark");
	Else
		CommonClientServer.DeleteDynamicListFilterGroupItems(Projects, "DeletionMark", False);
		CommonClientServer.DeleteDynamicListFilterGroupItems(ProjectPhases, "DeletionMark", False);
	EndIf;
	
	Items.ShowMarkedToDelete.Check = ShowMarkedToDelete;
	
EndProcedure

&AtServer
Procedure SwitchFilterByProject()
	
	Projects.Parameters.SetParameterValue("OnlyMyProjects", OnlyMyProjects);
	
EndProcedure

&AtClient
Procedure ExpandProjectTree()
	
	For Each TreeRow In ThisObject.ProjectTree.GetItems() Do
		Items.ProjectTree.Expand(TreeRow.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Procedure FindProjectsAndProjectPhases()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Projects.Ref AS ObjectOwner,
	|	Projects.Ref AS SearchObject,
	|	Projects.Description AS SearchValue,
	|	Projects.Description AS OwnerDescription,
	|	Projects.Description AS ObjectDescription
	|FROM
	|	Catalog.Projects AS Projects
	|WHERE
	|	NOT Projects.DeletionMark
	|	AND Projects.Description LIKE &SearchString
	|	AND (NOT &OnlyMyProjects
	|			OR &CurrentUser = Projects.Manager)
	|
	|UNION ALL
	|
	|SELECT
	|	Projects.Ref,
	|	ProjectPhases.Ref,
	|	ProjectPhases.Description,
	|	Projects.Description,
	|	ProjectPhases.Description
	|FROM
	|	Catalog.ProjectPhases AS ProjectPhases
	|		INNER JOIN Catalog.Projects AS Projects
	|		ON ProjectPhases.Owner = Projects.Ref
	|WHERE
	|	NOT ProjectPhases.DeletionMark
	|	AND Projects.DeletionMark = FALSE
	|	AND ProjectPhases.Description LIKE &SearchString
	|	AND (NOT &OnlyMyProjects
	|			OR &CurrentUser = Projects.Manager)
	|
	|ORDER BY
	|	OwnerDescription,
	|	ObjectDescription
	|TOTALS BY
	|	ObjectOwner";
	
	Query.SetParameter("SearchString", "%" + SearchString + "%");
	Query.SetParameter("CurrentUser", CurrentUser);
	Query.SetParameter("OnlyMyProjects", OnlyMyProjects);
	
	Result = Query.Execute();
	Selection = Result.Select(QueryResultIteration.ByGroups);
	
	TreeRoot = ProjectTree.GetItems();
	TreeRoot.Clear();
	
	While Selection.Next() Do
		
		If Not Items.ProjectTree.Visible Then
			Items.ProjectTree.Visible = True;
		EndIf;
		
		NewProject = TreeRoot.Add();
		NewProject.Description = Selection.OwnerDescription;
		NewProject.Ref = Selection.ObjectOwner;
		NewProject.Owner = Selection.ObjectOwner;
		NewProject.PictureNumber = 1;
		
		ProjectPhasesSelection = Selection.Select();
		While ProjectPhasesSelection.Next() Do
			
			ObjectType = TypeOf(ProjectPhasesSelection.SearchObject);
			If ObjectType <> Type("CatalogRef.ProjectPhases") Then
				Continue;
			EndIf;
			
			NewProjectPhase = NewProject.GetItems().Add();
			NewProjectPhase.Description = ProjectPhasesSelection.ObjectDescription;
			NewProjectPhase.Ref = ProjectPhasesSelection.SearchObject;
			NewProjectPhase.Owner = ProjectPhasesSelection.ObjectOwner;
			NewProjectPhase.IsPhase = True;
			NewProjectPhase.PictureNumber = 0;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetVisibilityOfProjectSearchResult(Visible);
	
	If Visible Then
		Items.Pages.CurrentPage = Items.PageTree;
	Else
		Items.Pages.CurrentPage = Items.PagesLists;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearSearch()
	
	SearchEnabled = False;
	SetVisibilityOfProjectSearchResult(SearchEnabled);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceOnCreate()
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ProjectPhases.SummaryPhase");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font("MS Shell Dlg", 8, True, False, False, False, 100));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProjectPhases");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion