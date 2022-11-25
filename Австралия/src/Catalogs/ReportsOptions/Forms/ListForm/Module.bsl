#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ClientParameters = ReportsOptions.ClientParameters();
	
	IncludeSubordinateSubsystems = True;
	
	ValuesTree = ReportsOptionsCached.CurrentUserSubsystems().Copy();
	SubsystemsTreeFillInFullPresentation(ValuesTree.Rows);
	ValueToFormAttribute(ValuesTree, "SubsystemsTree");
	
	SubsystemsTreeCurrentRow = -1;
	Items.SubsystemsTree.CurrentRow = 0;
	If Parameters.ChoiceMode = True Then
		FormOperationMode = "Selection";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.List.Representation = TableRepresentation.List;
	ElsIf Parameters.Property("SectionRef") Or Parameters.Property("SectionRef") Then
		FormOperationMode = "AllReportsInSection";
		TraversalArray = New Array;
		TraversalArray.Add(SubsystemsTree.GetItems()[0]);
		While TraversalArray.Count() > 0 Do
			ParentRows = TraversalArray[0].GetItems();
			TraversalArray.Delete(0);
			For Each TreeRow In ParentRows Do
				If TreeRow.Ref = Parameters.SectionRef Then
					Items.SubsystemsTree.CurrentRow = TreeRow.GetID();
					TraversalArray.Clear();
					Break;
				Else
					TraversalArray.Add(TreeRow);
				EndIf;
			EndDo;
		EndDo;
	Else
		FormOperationMode = "List";
		CommonClientServer.SetFormItemProperty(
			Items,
			"Change",
			"Representation",
			ButtonRepresentation.PictureAndText);
		CommonClientServer.SetFormItemProperty(
			Items,
			"PlaceInSections",
			"OnlyInAllActions",
			False);
	EndIf;
	
	GlobalSettings = ReportsOptions.GlobalSettings();
	Items.SearchString.InputHint = GlobalSettings.Search.InputHint;
	
	WindowOptionsKey = FormOperationMode;
	PurposeUseKey = FormOperationMode;
	
	SetListPropertyByFormParameter("ChoiceMode");
	SetListPropertyByFormParameter("ChoiceFoldersAndItems");
	SetListPropertyByFormParameter("MultipleChoice");
	SetListPropertyByFormParameter("CurrentRow");
	
	If Parameters.ChoiceMode Then
		CommonClientServer.SetFormItemProperty(
			Items,
			"SELECT",
			"DefaultButton",
			True);
	Else
		CommonClientServer.SetFormItemProperty(
			Items,
			"SELECT",
			"Visible",
			False);
	EndIf;
	
	FullRightsToOptions = ReportsOptions.FullRightsToOptions();
	If Not FullRightsToOptions Then
		CommonClientServer.SetFormItemProperty(
			Items,
			"FilterReportType",
			"Visible",
			False);
	EndIf;
	
	ChoiceList = Items.FilterReportType.ChoiceList;
	ChoiceList.Add(1, NStr("ru = 'Все, кроме внешних'; en = 'Everything except the external'; pl = 'Wszystkie, oprócz zewnętrznych';es_ES = 'Todos excepto externos';es_CO = 'Todos excepto externos';tr = 'Harici olanlar dışında hepsi';it = 'Tutto tranne l''esterno';de = 'Alle, außer extern'"));
	ChoiceList.Add(Enums.ReportTypes.Internal,     NStr("ru = 'Внутренние'; en = 'Internal'; pl = 'Wewnętrzne';es_ES = 'Interno';es_CO = 'Interno';tr = 'Dahili';it = 'Interno';de = 'Interne'"));
	ChoiceList.Add(Enums.ReportTypes.Extension,     NStr("ru = 'Расширения'; en = 'Extensions'; pl = 'Rozszerzenia';es_ES = 'Extensiones';es_CO = 'Extensiones';tr = 'Uzantılar';it = 'Estensioni';de = 'Erweiterungen'"));
	ChoiceList.Add(Enums.ReportTypes.Additional, NStr("ru = 'Дополнительные'; en = 'Additional'; pl = 'Dodatkowe';es_ES = 'Adicional';es_CO = 'Adicional';tr = 'Ek';it = 'Aggiuntivi';de = 'Zusätzlich'"));
	ChoiceList.Add(Enums.ReportTypes.External,        NStr("ru = 'Внешняя'; en = 'External'; pl = 'Zewnętrzne';es_ES = 'Externo';es_CO = 'Externo';tr = 'Harici';it = 'Esterno';de = 'Extern'"));
	
	Parameters.Property("SearchString", SearchString);
	If Parameters.Filter.Property("ReportType", FilterReportType) Then
		Parameters.Filter.Delete("ReportType");
	EndIf;
	If Parameters.Property("OptionsOnly") Then
		If Parameters.OptionsOnly Then
			CommonClientServer.SetDynamicListFilterItem(
				List,
				"VariantKey",
				"",
				DataCompositionComparisonType.NotEqual,
				,
				,
				DataCompositionSettingsItemViewMode.Normal);
		EndIf;
	EndIf;
	
	PersonalListSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		"Catalog.ReportsOptions.ListForm");
	If PersonalListSettings <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(PersonalListSettings.SearchStringSelectionList);
	EndIf;
	
	List.Parameters.SetParameterValue("InternalType",     Enums.ReportTypes.Internal);
	List.Parameters.SetParameterValue("ExtensionType",     Enums.ReportTypes.Extension);
	List.Parameters.SetParameterValue("AdditionalType", Enums.ReportTypes.Additional);
	List.Parameters.SetParameterValue("AvailableReports", ReportsOptions.CurrentUserReports());
	List.Parameters.SetParameterValue("DIsabledApplicationOptions", New Array(ReportsOptionsCached.DIsabledApplicationOptions()));
	
	CurrentItem = Items.List;
	
	ReportsOptions.ComplementFiltersFromStructure(List.SettingsComposer.Settings.Filter, Parameters.Filter);
	Parameters.Filter.Clear();
	
	UpdateListContent("OnCreateAtServer");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If FormOperationMode = "AllReportsInSection" OR FormOperationMode = "Selection" Then
		Items.SubsystemsTree.Expand(SubsystemsTreeCurrentRow, True);
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsOptionsClientServer.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Then
		SubsystemsTreeCurrentRow = -1;
		AttachIdleHandler("SubsystemsTreeRowActivationHandler", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterReportTypeOnChange(Item)
	UpdateListContent();
EndProcedure

&AtClient
Procedure FilterReportTypeClear(Item, StandardProcessing)
	StandardProcessing = False;
	FilterReportType = Undefined;
	UpdateListContent();
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	UpdateListContentClient("SearchStringOnChange");
EndProcedure

&AtClient
Procedure IncludingSubordinateSubsystemsOnChange(Item)
	SubsystemsTreeCurrentRow = -1;
	AttachIdleHandler("SubsystemsTreeRowActivationHandler", 0.1, True);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSubsystemsTree

&AtClient
Procedure SubsystemsTreeBeforeChangeRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeOnActivateRow(Item)
	AttachIdleHandler("SubsystemsTreeRowActivationHandler", 0.1, True);
EndProcedure

&AtClient
Procedure SubsystemsTreeDrag(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	PlacementParameters = New Structure("Variants, Action, Destination, Source"); //OptionsArray, Total, Presentation
	PlacementParameters.Variants = New Structure("Array, Total, Presentation");
	PlacementParameters.Variants.Array = DragParameters.Value;
	PlacementParameters.Variants.Total  = DragParameters.Value.Count();
	
	If PlacementParameters.Variants.Total = 0 Then
		Return;
	EndIf;
	
	RowDestination = SubsystemsTree.FindByID(Row);
	If RowDestination = Undefined OR RowDestination.Priority = "" Then
		Return;
	EndIf;
	
	PlacementParameters.Destination = New Structure("Ref, FullPresentation, ID");
	FillPropertyValues(PlacementParameters.Destination, RowDestination);
	PlacementParameters.Destination.ID = RowDestination.GetID();
	
	SourceRow = Items.SubsystemsTree.CurrentData;
	PlacementParameters.Source = New Structure("Ref, FullPresentation, ID");
	If SourceRow = Undefined OR SourceRow.Priority = "" Then
		PlacementParameters.Action = "Copy";
	Else
		FillPropertyValues(PlacementParameters.Source, SourceRow);
		PlacementParameters.Source.ID = SourceRow.GetID();
		If DragParameters.Action = DragAction.Copy Then
			PlacementParameters.Action = "Copy";
		Else
			PlacementParameters.Action = "Move";
		EndIf;
	EndIf;
	
	If PlacementParameters.Source.Ref = PlacementParameters.Destination.Ref Then
		ShowMessageBox(, NStr("ru = 'Выбранные варианты отчетов уже в данном разделе.'; en = 'The selected report options are already in this section.'; pl = 'Wybrane opcje sprawozdania znajdują się już w tej sekcji.';es_ES = 'Las opciones del informe seleccionadas ya están en esta sección.';es_CO = 'Las opciones del informe seleccionadas ya están en esta sección.';tr = 'Seçilen rapor seçenekleri bu bölümde zaten var.';it = 'Le varianti di report selezionate sono già in questa sezione.';de = 'Die ausgewählten Berichtsoptionen befinden sich bereits in diesem Abschnitt.'"));
		Return;
	EndIf;
	
	If PlacementParameters.Variants.Total = 1 Then
		If PlacementParameters.Action = "Copy" Then
			QuestionTemplate = NStr("ru = 'Разместить ""%1"" в ""%4""?'; en = 'Place ""%1"" to ""%4""?'; pl = 'Umieść ""%1"" do ""%4""?';es_ES = '¿Colocar ""%1"" a ""%4""?';es_CO = '¿Colocar ""%1"" a ""%4""?';tr = '""%1"" ""%4"" ''te yerleştirilsin mi?';it = 'Posizionare ""%1"" per ""%4""?';de = 'Platzieren Sie ""%1"" nach ""%4""?'");
		Else
			QuestionTemplate = NStr("ru = 'Переместить ""%1"" из ""%3"" в ""%4""?'; en = 'Move ""%1"" from ""%3"" to ""%4""?'; pl = 'Przenieść ""%1"" z ""%3"" do ""%4""?';es_ES = '¿Mover ""%1"" desde ""%3"" a ""%4""?';es_CO = '¿Mover ""%1"" desde ""%3"" a ""%4""?';tr = '""%1"", ""%3"" ''dan ""%4"" ''a taşınsın mı?';it = 'Spostare ""%1"" da ""%3"" a ""%4""?';de = 'Bewegen Sie ""%1"" von ""%3"" nach ""%4""?'");
		EndIf;
		PlacementParameters.Variants.Presentation = String(PlacementParameters.Variants.Array[0]);
	Else
		PlacementParameters.Variants.Presentation = "";
		For Each OptionRef In PlacementParameters.Variants.Array Do
			PlacementParameters.Variants.Presentation = PlacementParameters.Variants.Presentation
			+ ?(PlacementParameters.Variants.Presentation = "", "", ", ")
			+ String(OptionRef);
			If StrLen(PlacementParameters.Variants.Presentation) > 23 Then
				PlacementParameters.Variants.Presentation = Left(PlacementParameters.Variants.Presentation, 20) + "...";
				Break;
			EndIf;
		EndDo;
		If PlacementParameters.Action = "Copy" Then
			QuestionTemplate = NStr("ru = 'Разместить варианты отчетов ""%1"" (%2 шт.) в ""%4""?'; en = 'Place report options ""%1"" (%2 pcs.) in ""%4""?'; pl = 'Umieścić opcje sprawozdania ""%1"" (%2 szt.) w ""%4""?';es_ES = '¿Colocar las opciones del informe ""%1"" (%2 piezas) a ""%4""?';es_CO = '¿Colocar las opciones del informe ""%1"" (%2 piezas) a ""%4""?';tr = '""%1"" rapor seçeneklerini (%2 adet.) ""%4"" ''te yerleştirilsin mi?';it = 'Inserire le varianti di report ""%1"" (%2 pz.) in ""%4""?';de = 'Platzieren Sie die Berichtsoptionen ""%1"" (%2 Stück) in ""%4""?'");
		Else
			QuestionTemplate = NStr("ru = 'Переместить варианты отчетов ""%1"" (%2 шт.) из ""%3"" в ""%4""?'; en = 'Move report options ""%1"" (%2 pcs.) from ""%3"" to ""%4""?'; pl = 'Przenieś opcje sprawozdania ""%1"" (%2 szt.) z ""%3"" do ""%4""?';es_ES = '¿Mover las opciones del informe ""%1"" (%2 piezas) desde ""%3"" a ""%4""?';es_CO = '¿Mover las opciones del informe ""%1"" (%2 piezas) desde ""%3"" a ""%4""?';tr = '""%1"" rapor seçenekleri (%2.) ""%3"" ''ten %4''e taşınsın mi?';it = 'Muovere le varianti di report ""%1"" (%2 pz.) da ""%3"" a ""%4""?';de = 'Verschieben Sie die Berichtsoptionen ""%1"" (%2 Stück) von ""%3"" nach ""%4""?'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		QuestionTemplate,
		PlacementParameters.Variants.Presentation,
		Format(PlacementParameters.Variants.Total, "NG=0"),
		PlacementParameters.Source.FullPresentation,
		PlacementParameters.Destination.FullPresentation);
	
	Handler = New NotifyDescription("SubsystemsTreeDragCompletion", ThisObject, PlacementParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	Cancel = True;
	ReportsOptionsClient.ShowReportSettings(Items.List.CurrentRow);
EndProcedure

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	If FormOperationMode = "AllReportsInSection" Then
		StandardProcessing = False;
		ReportsOptionsClient.OpenReportForm(ThisObject, Items.List.CurrentData);
	ElsIf FormOperationMode = "List" Then
		StandardProcessing = False;
		ReportsOptionsClient.ShowReportSettings(RowSelected);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunSearch(Command)
	UpdateListContentClient("RunSearch");
EndProcedure

&AtClient
Procedure Change(Command)
	ReportsOptionsClient.ShowReportSettings(Items.List.CurrentRow);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SubsystemsTreeFillInFullPresentation(RowsSet, ParentPresentation = "")
	For Each TreeRow In RowsSet Do
		If IsBlankString(TreeRow.Name) Then
			TreeRow.FullPresentation = "";
		ElsIf IsBlankString(ParentPresentation) Then
			TreeRow.FullPresentation = TreeRow.Presentation;
		Else
			TreeRow.FullPresentation = ParentPresentation + "." + TreeRow.Presentation;
		EndIf;
		SubsystemsTreeFillInFullPresentation(TreeRow.Rows, TreeRow.FullPresentation);
	EndDo;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Details.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Details");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.NoteText);
	
EndProcedure

&AtClient
Procedure SubsystemsTreeDragCompletion(Response, PlacementParameters) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecutionResult = PlaceOptionsToSubsystem(PlacementParameters);
	ReportsOptionsClient.UpdateOpenForms();
	
	If PlacementParameters.Variants.Total = ExecutionResult.Placed Then
		If PlacementParameters.Variants.Total = 1 Then
			If PlacementParameters.Action = "Move" Then
				Template = NStr("ru = 'Успешно перемещен в ""%1"".'; en = 'Successfully transferred to %1"".'; pl = 'Pomyślnie przeniesiono do %1"".';es_ES = 'Trasladado con éxito a %1"".';es_CO = 'Trasladado con éxito a %1"".';tr = '%1"" ''e başarı ile taşındı.';it = 'Trasferito con successo %1"" .';de = 'Erfolgreich übertragen auf %1"".'");
			Else
				Template = NStr("ru = 'Успешно размещен в ""%1"".'; en = 'Successfully placed in %1"".'; pl = 'Pomyślnie umieszczono w %1"".';es_ES = 'Colocado con éxito a %1"".';es_CO = 'Colocado con éxito a %1"".';tr = '%1"" ''e başarı ile yerleştirildi.';it = 'Inserito con successo in %1"" .';de = 'Erfolgreich platziert in %1"".'");
			EndIf;
			Text = PlacementParameters.Variants.Presentation;
			Ref = GetURL(PlacementParameters.Variants.Array[0]);
		Else
			If PlacementParameters.Action = "Move" Then
				Template = NStr("ru = 'Успешно перемещен в ""%1"".'; en = 'Successfully transferred to %1"".'; pl = 'Pomyślnie przeniesiono do %1"".';es_ES = 'Trasladado con éxito a %1"".';es_CO = 'Trasladado con éxito a %1"".';tr = '%1"" ''e başarı ile taşındı.';it = 'Trasferito con successo %1"" .';de = 'Erfolgreich übertragen auf %1"".'");
			Else
				Template = NStr("ru = 'Успешно размещен в ""%1"".'; en = 'Successfully placed in %1"".'; pl = 'Pomyślnie umieszczono w %1"".';es_ES = 'Colocado con éxito a %1"".';es_CO = 'Colocado con éxito a %1"".';tr = '%1"" ''e başarı ile yerleştirildi.';it = 'Inserito con successo in %1"" .';de = 'Erfolgreich platziert in %1"".'");
			EndIf;
			Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Варианты отчетов (%1).'; en = 'Report options (%1).'; pl = 'Opcje sprawozdania (%1).';es_ES = 'Opciones del informe (%1).';es_CO = 'Opciones del informe (%1).';tr = 'Rapor seçenekleri (%1).';it = 'Opzioni di report (%1).';de = 'Berichtsoptionen (%1)'"), Format(PlacementParameters.Variants.Total, "NZ=0; NG=0"));
			Ref = Undefined;
		EndIf;
		Template = StringFunctionsClientServer.SubstituteParametersToString(Template, PlacementParameters.Destination.FullPresentation);
		ShowUserNotification(Template, Ref, Text);
	Else
		ErrorsText = "";
		If Not IsBlankString(ExecutionResult.CannotBePlaced) Then
			ErrorsText = ?(ErrorsText = "", "", ErrorsText + Chars.LF + Chars.LF)
				+ NStr("ru = 'Не могут размещаться в командном интерфейсе:'; en = 'Cannot be placed in command interface:'; pl = 'Nie można umieścić w interfejsie poleceń:';es_ES = 'No puede colocarse en le interfaz de comandos:';es_CO = 'No puede colocarse en le interfaz de comandos:';tr = 'Komut arayüzüne yerleştirilemez:';it = 'Non può essere inserito nella interfaccia di comando:';de = 'Kann nicht in der Befehlsschnittstelle platziert werden:'")
				+ Chars.LF
				+ ExecutionResult.CannotBePlaced;
		EndIf;
		If Not IsBlankString(ExecutionResult.AlreadyPlaced) Then
			ErrorsText = ?(ErrorsText = "", "", ErrorsText + Chars.LF + Chars.LF)
				+ NStr("ru = 'Уже размещены в этом разделе:'; en = 'Already located in this section:'; pl = 'Już jest w tej sekcji:';es_ES = 'Ya ubicado en esta sección:';es_CO = 'Ya ubicado en esta sección:';tr = 'Bu bölümde zaten var:';it = 'Già situato in questa sezione:';de = 'Bereits in diesem Bereich:'")
				+ Chars.LF
				+ ExecutionResult.AlreadyPlaced;
		EndIf;
		
		If PlacementParameters.Action = "Move" Then
			Template = NStr("ru = 'Перемещено вариантов отчетов: %1 из %2.
				|Подробности:
				|%3'; 
				|en = 'Transferred report options: %1 out of %2.
				|Details:
				|%3'; 
				|pl = 'Przemieszczone warianty sprawozdań: %1 z %2.
				|Szczegóły:
				|%3';
				|es_ES = 'Trasladado variantes de informes: %1 de %2. 
				|Detalles:
				|%3';
				|es_CO = 'Trasladado variantes de informes: %1 de %2. 
				|Detalles:
				|%3';
				|tr = 'Rapor seçenekleri taşındı: %1 içinden %2. 
				| Detaylar: 
				|%3';
				|it = 'Opzioni di report trasferite: %1 di %2.
				|Dettagli: 
				|%3';
				|de = 'Verschobene Berichtsoptionen: %1 von %2.
				|Details:
				|%3'");
		Else
			Template = NStr("ru = 'Размещено вариантов отчетов: %1 из %2.
				|Подробности:
				|%3'; 
				|en = 'Placed report options: %1 of %2.
				|Details:
				|%3'; 
				|pl = 'Rozmieszczone warianty raportów: %1z %2.
				|Szczegóły:
				|%3';
				|es_ES = 'Colocado variantes de informes: %1 de %2. 
				|Detalles:
				|%3';
				|es_CO = 'Colocado variantes de informes: %1 de %2. 
				|Detalles:
				|%3';
				|tr = 'Rapor seçenekleri yerleştirildi: %1 içinden %2. 
				| Detaylar: 
				|%3';
				|it = 'Opzioni di report posizionate: %1 di %2.
				|Dettagli: 
				|%3';
				|de = 'Platzierte Berichtsoptionen: %1 von%2.
				|Details:
				|%3'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Undefined, 
			StringFunctionsClientServer.SubstituteParametersToString(Template, ExecutionResult.Placed, 
				PlacementParameters.Variants.Total, ErrorsText), QuestionDialogMode.OK);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetListPropertyByFormParameter(varKey)
	
	If Parameters.Property(varKey) AND ValueIsFilled(Parameters[varKey]) Then
		Items.List[varKey] = Parameters[varKey];
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateListContent(Val Event = "")
	PersonalSettingsChanged = False;
	If ValueIsFilled(SearchString) Then
		ChoiceList = Items.SearchString.ChoiceList;
		ListItem = ChoiceList.FindByValue(SearchString);
		If ListItem = Undefined Then
			ChoiceList.Insert(0, SearchString);
			PersonalSettingsChanged = True;
			If ChoiceList.Count() > 10 Then
				ChoiceList.Delete(10);
			EndIf;
		Else
			Index = ChoiceList.IndexOf(ListItem);
			If Index <> 0 Then
				ChoiceList.Move(Index, -Index);
				PersonalSettingsChanged = True;
			EndIf;
		EndIf;
		CurrentItem = Items.SearchString;
	EndIf;
	
	If Event = "SearchStringOnChange" AND PersonalSettingsChanged Then
		PersonalListSettings = New Structure("SearchStringSelectionList");
		PersonalListSettings.SearchStringSelectionList = Items.SearchString.ChoiceList.UnloadValues();
		Common.CommonSettingsStorageSave(
			ReportsOptionsClientServer.FullSubsystemName(),
			"Catalog.ReportsOptions.ListForm",
			PersonalListSettings);
	EndIf;
	
	SubsystemsTreeCurrentRow = Items.SubsystemsTree.CurrentRow;
	
	TreeRow = SubsystemsTree.FindByID(SubsystemsTreeCurrentRow);
	If TreeRow = Undefined Then
		Return;
	EndIf;
	
	AllSubsystems = Not ValueIsFilled(TreeRow.FullName);
	
	SearchParameters = New Structure;
	SearchParameters.Insert("DeletionMark", False);
	If ValueIsFilled(SearchString) Then
		SearchParameters.Insert("SearchString", SearchString);
		Items.List.InitialTreeView = InitialTreeView.ExpandAllLevels;
	Else
		Items.List.InitialTreeView = InitialTreeView.NoExpand;
	EndIf;
	SearchParameters.Insert("ExactFilterBySubsystems", Not AllSubsystems);
	If Not AllSubsystems Or ValueIsFilled(SearchString) Then
		SubsystemsArray = New Array;
		If Not AllSubsystems Then
			SubsystemsArray.Add(TreeRow.Ref);
		EndIf;
		If AllSubsystems Or IncludeSubordinateSubsystems Then
			AddRecursively(SubsystemsArray, TreeRow.GetItems());
		EndIf;
		SearchParameters.Insert("Subsystems", SubsystemsArray);
	EndIf;
	If ValueIsFilled(FilterReportType) Then
		ReportTypesArray = New Array;
		If FilterReportType = 1 Then
			ReportTypesArray.Add(Enums.ReportTypes.Internal);
			ReportTypesArray.Add(Enums.ReportTypes.Extension);
			ReportTypesArray.Add(Enums.ReportTypes.Additional);
		Else
			ReportTypesArray.Add(FilterReportType);
		EndIf;
		SearchParameters.Insert("ReportTypes", ReportTypesArray);
	EndIf;
	
	SearchResult = ReportsOptions.FindLinks(SearchParameters);
	UserOptions = ?(SearchResult = Undefined, New Array, SearchResult.References);
	List.Parameters.SetParameterValue("HasVariantFilter", SearchResult <> Undefined);
	List.Parameters.SetParameterValue("UserOptions", UserOptions);
	
EndProcedure

&AtClient
Procedure SubsystemsTreeRowActivationHandler()
	If SubsystemsTreeCurrentRow <> Items.SubsystemsTree.CurrentRow Then
		UpdateListContent();
	EndIf;
EndProcedure

&AtServer
Procedure AddRecursively(SubsystemsArray, TreeRowCollection)
	For Each TreeRow In TreeRowCollection Do
		SubsystemsArray.Add(TreeRow.Ref);
		AddRecursively(SubsystemsArray, TreeRow.GetItems());
	EndDo;
EndProcedure

&AtServer
Procedure SubsystemsTreeWritePropertyToArray(TreeRowsArray, PropertyName, RefsArray)
	For Each TreeRow In TreeRowsArray Do
		RefsArray.Add(TreeRow[PropertyName]);
		SubsystemsTreeWritePropertyToArray(TreeRow.GetItems(), PropertyName, RefsArray);
	EndDo;
EndProcedure

&AtServer
Function PlaceOptionsToSubsystem(PlacementParameters)
	SubsystemsToExclude = New Array;
	If PlacementParameters.Action = "Move" Then
		SourceRow = SubsystemsTree.FindByID(PlacementParameters.Source.ID);
		SubsystemsToExclude.Add(SourceRow.Ref);
		SubsystemsTreeWritePropertyToArray(SourceRow.GetItems(), "Ref", SubsystemsToExclude);
	EndIf;
	
	Placed = 0;
	AlreadyPlaced = "";
	CannotBePlaced = "";
	BeginTransaction();
	Try
		For Each OptionRef In PlacementParameters.Variants.Array Do
			If OptionRef.ReportType = Enums.ReportTypes.External Then
				CannotBePlaced = ?(CannotBePlaced = "", "", CannotBePlaced + Chars.LF)
					+ "  "
					+ String(OptionRef)
					+ " ("
					+ NStr("ru = 'внешняя'; en = 'external'; pl = 'zewnętrzne';es_ES = 'externo';es_CO = 'externo';tr = 'harici';it = 'esterno';de = 'extern'")
					+ ")";
				Continue;
			ElsIf OptionRef.DeletionMark Then
				CannotBePlaced = ?(CannotBePlaced = "", "", CannotBePlaced + Chars.LF)
					+ "  "
					+ String(OptionRef)
					+ " ("
					+ NStr("ru = 'помеченные на удаление'; en = 'marked for deletion'; pl = 'zaznaczony do usunięcia';es_ES = 'marcado para borrar';es_CO = 'marcado para borrar';tr = 'silinmek üzere işaretlendi';it = 'contrassegnato per l''eliminazione';de = 'ist zum Löschen vorgemerkt'")
					+ ")";
				Continue;
			EndIf;
			
			HasChanges = False;
			OptionObject = OptionRef.GetObject();
			
			RowDestination = OptionObject.Placement.Find(PlacementParameters.Destination.Ref, "Subsystem");
			If RowDestination = Undefined Then
				RowDestination = OptionObject.Placement.Add();
				RowDestination.Subsystem = PlacementParameters.Destination.Ref;
			EndIf;
			
			// Remove a row from a source subsystem.
			// Remember that to exclude a predefined option from a subsystem, you must clear the subsystem check 
			// box.
			If PlacementParameters.Action = "Move" Then
				For Each SubsystemToExclude In SubsystemsToExclude Do
					SourceRow = OptionObject.Placement.Find(SubsystemToExclude, "Subsystem");
					If SourceRow <> Undefined Then
						If SourceRow.Use Then
							SourceRow.Use = False;
							If Not HasChanges Then
								FillPropertyValues(RowDestination, SourceRow, "Important, SeeAlso");
								HasChanges = True;
							EndIf;
						EndIf;
						SourceRow.Important  = False;
						SourceRow.SeeAlso = False;
					ElsIf Not OptionObject.Custom Then
						SourceRow = OptionObject.Placement.Add();
						SourceRow.Subsystem = SubsystemToExclude;
						HasChanges = True;
					EndIf;
				EndDo;
			EndIf;
			
			// Register a row in a destination subsystem.
			If Not RowDestination.Use Then
				HasChanges = True;
				RowDestination.Use = True;
			EndIf;
			
			If HasChanges Then
				Placed = Placed + 1;
				OptionObject.Write();
			Else
				AlreadyPlaced = ?(AlreadyPlaced = "", "", AlreadyPlaced + Chars.LF)
					+ "  "
					+ String(OptionRef);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If PlacementParameters.Action = "Move" AND Placed > 0 Then
		Items.SubsystemsTree.CurrentRow = PlacementParameters.Destination.ID;
		UpdateListContent();
	EndIf;
	
	Return New Structure("Placed,AlreadyPlaced,CannotBePlaced", Placed, AlreadyPlaced, CannotBePlaced);
EndFunction

&AtClient
Procedure UpdateListContentClient(Event)
	Msrmnt = StartMeasurement(Event);
	UpdateListContent(Event);
	EndMeasurement(Msrmnt);
EndProcedure

&AtClient
Function StartMeasurement(Event)
	If Not ClientParameters.RunMeasurements Then
		Return Undefined;
	EndIf;
	
	If ValueIsFilled(SearchString) AND (Event = "SearchStringOnChange" Or Event = "RunSearch") Then
		Name = "ReportsList.Search";
	Else
		Return Undefined;
	EndIf;
	
	Comment = ClientParameters.MeasurementsPrefix;
	
	If ValueIsFilled(SearchString) Then
		Comment = Comment
			+ "; " + NStr("ru = 'Поиск:'; en = 'Search:'; pl = 'Wyszukiwanie:';es_ES = 'Búsqueda:';es_CO = 'Búsqueda:';tr = 'Arama:';it = 'Ricerca:';de = 'Suche:'") + " " + String(SearchString)
			+ "; " + NStr("ru = 'Включая подчиненные:'; en = 'Recursive:'; pl = 'Łącznie z podporządkowanymi:';es_ES = 'Incluso subordinados:';es_CO = 'Incluso subordinados:';tr = 'Alt sıra dahil:';it = 'Ricorsivo:';de = 'Einschließlich der Untergebenen:'") + " " + String(IncludeSubordinateSubsystems);
	Else
		Comment = Comment + "; " + NStr("ru = 'Без поиска'; en = 'Without searching'; pl = 'Bez wyszukiwania';es_ES = 'Sin buscar';es_CO = 'Sin buscar';tr = 'Aramadan';it = 'Senza ricerca';de = 'Ohne Suche'");
	EndIf;
	
	Msrmnt = New Structure("ModulePerformanceMonitorClient, ID");
	Msrmnt.ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
	Msrmnt.ID = Msrmnt.ModulePerformanceMonitorClient.StartTimeMeasurement(False, Name);
	Msrmnt.ModulePerformanceMonitorClient.SetMeasurementComment(Msrmnt.ID, Comment);
	Return Msrmnt;
EndFunction

&AtClient
Procedure EndMeasurement(Msrmnt)
	If Msrmnt <> Undefined Then
		Msrmnt.ModulePerformanceMonitorClient.StopTimeMeasurement(Msrmnt.ID);
	EndIf;
EndProcedure

#EndRegion