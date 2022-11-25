#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetColorsAndConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	FuzzySearch = Common.AttachAddInFromTemplate("FuzzyStringMatchExtension", "CommonTemplate.StringSearchAddIn");
	If FuzzySearch <> Undefined Then 
		FuzzySearch = True;
	EndIf;
	
	FormSettings = Common.CommonSettingsStorageLoad(FormName, "");
	If FormSettings = Undefined Then
		FormSettings = New Structure;
		FormSettings.Insert("TakeAppliedRulesIntoAccount", True);
		FormSettings.Insert("DuplicatesSearchArea",        "");
		FormSettings.Insert("DCSettings",                Undefined);
		FormSettings.Insert("SearchRules",              Undefined);
	EndIf;
	FillPropertyValues(FormSettings, Parameters);
	
	OnCreateAtServerDataInitialization(FormSettings);
	
	InitFilterComposerAndRules(FormSettings);
	
	// The schema must be always reformed, composer settings - by AreaToSearchForDuplicates.
	
	// Permanent Interface
	StatePresentation = Items.NoSearchPerformed.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("ru = 'Поиск дублей не выполнялся. 
	                                        |Задайте условия отбора и сравнения и нажмите ""Найти дубли"".'; 
	                                        |en = 'Duplicate search was not performed.
	                                        |Specify filter and comparison conditions, and then click ""Find duplicates"".'; 
	                                        |pl = 'Wyszukiwanie duplikatów nie jest wykonywane w toku. 
	                                        |Ustaw filtr i kryteria porównania i kliknij Znajdź duplikaty.';
	                                        |es_ES = 'Búsqueda de duplicados no está en progreso. 
	                                        |Establecer el filtro y los criterios de comparación, y hacer clic en Buscar duplicados.';
	                                        |es_CO = 'Búsqueda de duplicados no está en progreso. 
	                                        |Establecer el filtro y los criterios de comparación, y hacer clic en Buscar duplicados.';
	                                        |tr = 'Yinelenen arama devam etmiyor. 
	                                        |Filtre ve karşılaştırma kriterlerini ayarlayın ve Çiftleri bul''u tıklayın.';
	                                        |it = 'Ricerca duplicati non eseguita.
	                                        |Specifica i filtri e le condizioni di comparazione, poi clicca ""Trova duplicati"".';
	                                        |de = 'Duplikatsuche wird nicht ausgeführt.
	                                        |Legen Sie Filter- und Vergleichskriterien fest und klicken Sie auf Duplikate suchen.'");
	StatePresentation.Picture = Items.Warning32.Picture;
	
	StatePresentation = Items.PerformSearch.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("ru = 'Поиск дублей...'; en = 'Searching for duplicates...'; pl = 'Wyszukiwanie duplikatów...';es_ES = 'Búsqueda de duplicados...';es_CO = 'Búsqueda de duplicados...';tr = 'Çiftleri arama...';it = 'Ricerca di duplicati...';de = 'Duplikatsuch...'");
	StatePresentation.Picture = Items.TimeConsumingOperation48.Picture;
	
	StatePresentation = Items.Deletion.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("ru = 'Удаление дублей...'; en = 'Deleting duplicates...'; pl = 'Usuwanie duplikatów ...';es_ES = 'Eliminando los duplicados ...';es_CO = 'Eliminando los duplicados ...';tr = 'Çiftleri silme...';it = 'Eliminazione duplicati...';de = 'Duplikate löschen...'");
	StatePresentation.Picture = Items.TimeConsumingOperation48.Picture;
	
	StatePresentation = Items.DuplicatesNotFound.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("ru = 'Не обнаружено дублей по указанным параметрам.
	                                        |Измените условия отбора и сравнения, нажмите ""Найти дубли""'; 
	                                        |en = 'No duplicates found by the specified parameters.
	                                        |Change filter and comparison conditions, and then click ""Find duplicates""'; 
	                                        |pl = 'Duplikaty według określonych parametrów nie zostały znalezione.
	                                        |Zmień kryteria filtrowania i porównania, kliknij Znajdź duplikaty';
	                                        |es_ES = 'Duplicados por parámetros especificados no se han encontrado.
	                                        |Cambiar el filtro y los criterios de comparación, hacer clic en Buscar duplicados';
	                                        |es_CO = 'Duplicados por parámetros especificados no se han encontrado.
	                                        |Cambiar el filtro y los criterios de comparación, hacer clic en Buscar duplicados';
	                                        |tr = 'Belirtilen parametrelere sahip kopyalar bulunamadı. 
	                                        |Filtre ve karşılaştırma ölçütlerini değiştirin, Çiftleri bul''u tıklayın.';
	                                        |it = 'Nessun duplicato trovato con parametri specificati.
	                                        |Cambia i filtri e le condizioni di comparazione e poi clicca ""Trova duplicati""';
	                                        |de = 'Duplikate nach angegebenen Parametern werden nicht gefunden.
	                                        |Ändern Sie Filter und Vergleichskriterien, klicken Sie auf Duplikate suchen'");
	StatePresentation.Picture = Items.Warning32.Picture;
	
	// Autosaving settings
	SavedInSettingsDataModified = True;
	
	// Initialization of step-by-step wizard steps.
	InitializeStepByStepWizardSettings();
	
	// 1. No search executed.
	SearchStep = AddWizardStep(Items.NoSearchPerformedStep);
	SearchStep.BackButton.Visible = False;
	SearchStep.NextButton.Title = NStr("ru = 'Найти дубли >'; en = 'Find duplicates >'; pl = 'Znajdź duplikaty >';es_ES = 'Buscar duplicados >';es_CO = 'Buscar duplicados >';tr = 'Çiftleri bul >';it = 'Trova duplicati >';de = 'Duplikate finden >'");
	SearchStep.NextButton.ToolTip = NStr("ru = 'Найти дубли по указанным критериям'; en = 'Find duplicates by the specified criteria'; pl = 'Znajdź duplikaty według określonych kryteriów';es_ES = 'Buscar los duplicados según los criterios especificados';es_CO = 'Buscar los duplicados según los criterios especificados';tr = 'Belirtilen kriterlere göre kopyaları bulun';it = 'Trova duplicati secondo criteri specifici';de = 'Duplikate nach den angegebenen Kriterien finden'");
	SearchStep.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	SearchStep.CancelButton.ToolTip = NStr("ru = 'Отказаться от поиска и замены дублей'; en = 'Cancel search and replacement of duplicates'; pl = 'Odmów wyszukiwania i zastępowania duplikatów';es_ES = 'Rechazar la búsqueda y el reemplazo de duplicados';es_CO = 'Rechazar la búsqueda y el reemplazo de duplicados';tr = 'Çiftleri aramayı ve değiştirmeyi reddet';it = 'Annulla ricerca e sostituzione duplicati';de = 'Verweigert das Suchen und Ersetzen von Duplikaten'");
	
	// 2. Time-consuming search.
	Step = AddWizardStep(Items.PerformSearchStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Прервать поиск дублей'; en = 'Abort searching for duplicates'; pl = 'Zatrzymaj wyszukiwanie duplikatów';es_ES = 'Parar la búsqueda de duplicados';es_CO = 'Parar la búsqueda de duplicados';tr = 'Çiftleri aramayı durdur';it = 'Termina la ricerca di duplicati';de = 'Stoppen Sie die Duplikatsuche'");
	
	// 3. Search result processing, main item selection.
	Step = AddWizardStep(Items.MainItemSelectionStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Title = NStr("ru = 'Удалить дубли >'; en = 'Delete duplicates >'; pl = 'Usuń duplikaty >';es_ES = 'Borrar los duplicados >';es_CO = 'Borrar los duplicados >';tr = 'Çiftleri sil >';it = 'Elimina duplicati >';de = 'Duplikate löschen >'");
	Step.NextButton.ToolTip = NStr("ru = 'Удалить дубли'; en = 'Delete duplicates'; pl = 'Usuń duplikaty';es_ES = 'Borrar duplicados';es_CO = 'Borrar duplicados';tr = 'Çiftleri sil';it = 'Elimina duplicati';de = 'Duplikate löschen'");
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Отказаться от поиска и замены дублей'; en = 'Cancel search and replacement of duplicates'; pl = 'Odmów wyszukiwania i zastępowania duplikatów';es_ES = 'Rechazar la búsqueda y el reemplazo de duplicados';es_CO = 'Rechazar la búsqueda y el reemplazo de duplicados';tr = 'Çiftleri aramayı ve değiştirmeyi reddet';it = 'Annulla ricerca e sostituzione duplicati';de = 'Verweigert das Suchen und Ersetzen von Duplikaten'");
	
	// 4. Time-consuming deletion of duplicates.
	Step = AddWizardStep(Items.DeletionStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Прервать удаление дублей'; en = 'Abort duplicate deletion'; pl = 'Zatrzymaj usuwanie duplikatów';es_ES = 'Parar la eliminación de duplicados';es_CO = 'Parar la eliminación de duplicados';tr = 'Çiftleri silmeyi durdur';it = 'Annulla duplicazione dell''eliminazione';de = 'Stoppen Sie die Entfernung von Duplikaten'");
	
	// 5. Successful deletion.
	Step = AddWizardStep(Items.SuccessfulDeletionStep);
	Step.BackButton.Title = NStr("ru = '< Новый поиск'; en = '< New search'; pl = '< Nowe wyszukiwanie';es_ES = '< Nueva búsqueda';es_CO = '< Nueva búsqueda';tr = '< Yeni arama';it = '< Nuova ricerca';de = '< Neue Suche'");
	Step.BackButton.ToolTip = NStr("ru = 'Начать новый поиск с другими параметрами'; en = 'Start a new search with other parameters'; pl = 'Rozpocznij nowe wyszukiwanie z innymi parametrami';es_ES = 'Iniciar una nueva búsqueda con parámetros diferentes';es_CO = 'Iniciar una nueva búsqueda con parámetros diferentes';tr = 'Farklı parametrelerle yeni arama başlat';it = 'Avvia una nuova ricerca con altri parametri';de = 'Starten Sie die neue Suche mit verschiedenen Parametern'");
	Step.NextButton.Visible = False;
	Step.CancelButton.DefaultButton = True;
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	
	// 6. Incomplete deletion.
	Step = AddWizardStep(Items.UnsuccessfulReplacementsStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Title = NStr("ru = 'Повторить удаление >'; en = 'Retry deletion >'; pl = 'Powtórz usuwanie >';es_ES = 'Repetir la eliminación >';es_CO = 'Repetir la eliminación >';tr = 'Silme işlemini tekrarla>';it = 'Riprova eliminazione >';de = 'Löschen wiederholen >'");
	Step.NextButton.ToolTip = NStr("ru = 'Удалить дубли'; en = 'Delete duplicates'; pl = 'Usuń duplikaty';es_ES = 'Borrar duplicados';es_CO = 'Borrar duplicados';tr = 'Çiftleri sil';it = 'Elimina duplicati';de = 'Duplikate löschen'");
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	
	// 7. No duplicates found.
	Step = AddWizardStep(Items.DuplicatesNotFoundStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Title = NStr("ru = 'Найти дубли >'; en = 'Find duplicates >'; pl = 'Znajdź duplikaty >';es_ES = 'Buscar duplicados >';es_CO = 'Buscar duplicados >';tr = 'Çiftleri bul >';it = 'Trova duplicati >';de = 'Duplikate finden >'");
	Step.NextButton.ToolTip = NStr("ru = 'Найти дубли по указанным критериям'; en = 'Find duplicates by the specified criteria'; pl = 'Znajdź duplikaty według określonych kryteriów';es_ES = 'Buscar los duplicados según los criterios especificados';es_CO = 'Buscar los duplicados según los criterios especificados';tr = 'Belirtilen kriterlere göre kopyaları bulun';it = 'Trova duplicati secondo criteri specifici';de = 'Duplikate nach den angegebenen Kriterien finden'");
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	
	// 8. Runtime errors.
	Step = AddWizardStep(Items.ErrorOccurredStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	
	// Updating form items.
	WizardSettings.CurrentStep = SearchStep;
	VisibleEnabled(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Running wizard.
	OnActivateWizardStep();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	If Not WizardSettings.ShowDialogBeforeClose Then
		Return;
	EndIf;
	If Exit Then
		Return;
	EndIf;
	
	Cancel = True;
	CurrentPage = Items.WizardSteps.CurrentPage;
	If CurrentPage = Items.PerformSearchStep Then
		QuestionText = NStr("ru = 'Прервать поиск дублей и закрыть форму?'; en = 'Stop searching for duplicates and close the form?'; pl = 'Zaprzestać szukania duplikatów i zamknij formularz?';es_ES = '¿Parar la búsqueda de duplicados y cerrar el formulario?';es_CO = '¿Parar la búsqueda de duplicados y cerrar el formulario?';tr = 'Çiftleri araması durdurulsun ve form kapatılsın mı?';it = 'Interrompere la ricerca di duplicati e chiudere il modulo?';de = 'Stoppen Sie die Suche nach Duplikaten und schließen Sie das Formular?'");
	ElsIf CurrentPage = Items.DeletionStep Then
		QuestionText = NStr("ru = 'Прервать удаление дублей и закрыть форму?'; en = 'Stop deleting duplicates and close the form?'; pl = 'Zaprzestać usuwania duplikatów i zamknij formularz?';es_ES = '¿Parar la eliminación de duplicados y cerrar el formulario?';es_CO = '¿Parar la eliminación de duplicados y cerrar el formulario?';tr = 'Çiftleri değiştirmeyi bırak ve formu kapat?';it = 'Interrompere la cancellazione di duplicati e chiudere il modulo?';de = 'Stoppen Sie das Löschen von Duplikaten und schließen Sie das Formular?'");
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Abort, NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'"));
	Buttons.Add(DialogReturnCode.No,      NStr("ru = 'Не прерывать'; en = 'Do not stop'; pl = 'Nie przerywać';es_ES = 'No interrumpir';es_CO = 'No interrumpir';tr = 'Kesme';it = 'Non fermare';de = 'Nicht unterbrechen'"));
	
	Handler = New NotifyDescription("AfterConfirmCancelJob", ThisObject);
	
	ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.No);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AreaToSearchForDuplicatesStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	Name = FullFormName("DuplicatesSearchArea");
	
	FormParameters = New Structure;
	FormParameters.Insert("SettingsAddress", SettingsAddress);
	FormParameters.Insert("DuplicatesSearchArea", DuplicatesSearchArea);
	
	Handler = New NotifyDescription("DuplicatesSearchAreaSelectionCompletion", ThisObject);
	
	OpenForm(Name, FormParameters, ThisObject, , , , Handler);
EndProcedure

&AtClient
Procedure DuplicatesSearchAreaSelectionCompletion(Result, ExecutionParameters) Export
	If TypeOf(Result) <> Type("String") Then
		Return;
	EndIf;
	
	DuplicatesSearchArea = Result;
	InitFilterComposerAndRules(Undefined);
	GoToWizardStep(Items.NoSearchPerformedStep);
EndProcedure

&AtClient
Procedure AreaToSearchForDuplicatesOnChange(Item)
	InitFilterComposerAndRules(Undefined);
	GoToWizardStep(Items.NoSearchPerformedStep);
EndProcedure

&AtClient
Procedure AreaToSearchForDuplicatesClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure AllUnprocessedItemsUsageInstancesClick(Item)
	
	ShowUsageInstances(UnprocessedDuplicates);
	
EndProcedure

&AtClient
Procedure AllUsageInstancesClick(Item)
	
	ShowUsageInstances(FoundDuplicates);
	
EndProcedure

&AtClient
Procedure FilterRulesPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	AttachIdleHandler("OnStartSelectFilterRules", 0.1, True);
EndProcedure

&AtClient
Procedure OnStartSelectFilterRules()
	
	Name = FullFormName("FilterRules");
	
	ListItem = Items.DuplicatesSearchArea.ChoiceList.FindByValue(DuplicatesSearchArea);
	If ListItem = Undefined Then
		PresentationOfAreaToSearchForDuplicates = Undefined;
	Else
		PresentationOfAreaToSearchForDuplicates = ListItem.Presentation;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CompositionSchemaAddress",            CompositionSchemaAddress);
	FormParameters.Insert("FilterComposerSettingsAddress", FilterComposerSettingsAddress());
	FormParameters.Insert("MasterFormID",      UUID);
	FormParameters.Insert("FilterAreaPresentation",      PresentationOfAreaToSearchForDuplicates);
	
	Handler = New NotifyDescription("FilterRulesSelectionCompletion", ThisObject);
	
	OpenForm(Name, FormParameters, ThisObject, , , , Handler);
	
EndProcedure

&AtClient
Procedure FilterRulesSelectionCompletion(ResultAddress, ExecutionParameters) Export
	If TypeOf(ResultAddress) <> Type("String") Or Not IsTempStorageURL(ResultAddress) Then
		Return;
	EndIf;
	UpdateFilterComposer(ResultAddress);
	GoToWizardStep(Items.NoSearchPerformedStep);
EndProcedure

&AtClient
Procedure FilterRulesPresentationClearing(Item, StandardProcessing)
	StandardProcessing = False;
	PrefilterComposer.Settings.Filter.Items.Clear();
	GoToWizardStep(Items.NoSearchPerformedStep);
	SaveUserSettingsSSL();
EndProcedure

&AtClient
Procedure SearchRulesPresentationClick(Item, StandardProcessing)
	StandardProcessing = False;
	
	Name = FullFormName("SearchRules");
	
	ListItem = Items.DuplicatesSearchArea.ChoiceList.FindByValue(DuplicatesSearchArea);
	If ListItem = Undefined Then
		PresentationOfAreaToSearchForDuplicates = Undefined;
	Else
		PresentationOfAreaToSearchForDuplicates = ListItem.Presentation;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("DuplicatesSearchArea",        DuplicatesSearchArea);
	FormParameters.Insert("AppliedRuleDetails",   AppliedRuleDetails);
	FormParameters.Insert("SettingsAddress",              SearchRuleSettingsAddress());
	FormParameters.Insert("FilterAreaPresentation", PresentationOfAreaToSearchForDuplicates);
	
	Handler = New NotifyDescription("SearchRulesSelectionCompletion", ThisObject);
	
	OpenForm(Name, FormParameters, ThisObject, , , , Handler);
EndProcedure

&AtClient
Procedure SearchRulesSelectionCompletion(ResultAddress, ExecutionParameters) Export
	If TypeOf(ResultAddress) <> Type("String") Or Not IsTempStorageURL(ResultAddress) Then
		Return;
	EndIf;
	UpdateSearchRules(ResultAddress);
	GoToWizardStep(Items.NoSearchPerformedStep);
EndProcedure

&AtClient
Procedure DetailsRefClick(Item)
	StandardSubsystemsClient.ShowDetailedInfo(Undefined, Item.ToolTip);
EndProcedure

#EndRegion

#Region FoundDuplicatesTableEventHandlers

&AtClient
Procedure FoundDuplicatesOnActivateRow(Item)
	
	AttachIdleHandler("DuplicateRowActivationDeferredHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure DuplicateRowActivationDeferredHandler()
	RowID = Items.FoundDuplicates.CurrentRow;
	If RowID = Undefined Or RowID = CurrentRowID Then
		Return;
	EndIf;
	CurrentRowID = RowID;
	
	UpdateCandidateUsageInstances(RowID);
EndProcedure

&AtServer
Procedure UpdateCandidateUsageInstances(Val RowID)
	RowData = FoundDuplicates.FindByID(RowID);
	
	If RowData.GetParent() = Undefined Then
		// Group details
		ProbableDuplicateUsageInstances.Clear();
		
		OriginalDescription = Undefined;
		For Each Candidate In RowData.GetItems() Do
			If Candidate.Main Then
				OriginalDescription = Candidate.Description;
				Break;
			EndIf;
		EndDo;
		
		Items.CurrentDuplicatesGroupDetails.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для элемента ""%1"" найдено дублей: %2'; en = 'Duplicates found for item ""%1"": %2'; pl = 'Dla elementu ""%1"" znaleziono duplikatów: %2';es_ES = 'Para el artículo ""%1"" no se he encontrado duplicados: %2';es_CO = 'Para el artículo ""%1"" no se he encontrado duplicados: %2';tr = '""%2"" Öğesi için çiftler (%1) bulundu';it = 'Trovati duplicati per elementi ""%1"": %2';de = 'Für das Element ""%1"" Duplikate gefunden: %2'"),
			OriginalDescription,
			RowData.Count);
		
		Items.UsageInstancesPages.CurrentPage = Items.GroupDetails;
		Return;
	EndIf;
	
	// List of usage instances.
	UsageTable = GetFromTempStorage(UsageInstancesAddress);
	Filter = New Structure("Ref", RowData.Ref);
	
	ProbableDuplicateUsageInstances.Load(UsageTable.Copy(UsageTable.FindRows(Filter)));
	
	If RowData.Count = 0 Then
		Items.CurrentDuplicatesGroupDetails.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Элемент ""%1"" не используется'; en = 'Item ""%1"" is not used'; pl = 'Pozycja ""%1"" nie jest używana';es_ES = 'Artículo ""%1"" no se ha utilizado';es_CO = 'Artículo ""%1"" no se ha utilizado';tr = 'Öğe ""%1"" kullanılmadı';it = 'Elemento ""%1"" non viene utilizzato';de = 'Artikel ""%1"" wird nicht verwendet'"), 
			RowData.Description);
		
		Items.UsageInstancesPages.CurrentPage = Items.GroupDetails;
	Else
		Items.ProbableDuplicateUsageInstances.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Места использования ""%1"" (%2)'; en = 'Usage instances ""%1"" (%2)'; pl = 'Miejsca użycia ""%1"" (%2)';es_ES = 'Ubicaciones de uso ""%1"" (%2)';es_CO = 'Ubicaciones de uso ""%1"" (%2)';tr = 'Kullanıcı konumları ""%1"" (%2)';it = 'Utilizzare istanze ""%1"" (%2)';de = 'Verwendungsorte ""%1"" (%2)'"), 
			RowData.Description,
			RowData.Count);
		
		Items.UsageInstancesPages.CurrentPage = Items.UsageInstances;
	EndIf;
	
EndProcedure

&AtClient
Procedure FoundDuplicatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenDouplicateForm(Item.CurrentData);
	
EndProcedure

&AtClient
Procedure FoundDuplicatesCheckOnChange(Item)
	RowData = Items.FoundDuplicates.CurrentData;
	
	RowData.Check = RowData.Check % 2;
	
	ChangeCandidateMarksHierarchically(RowData);
	
	RecalculateFoundDuplicatesNumber();
	
	UpdateFoundDuplicatesStateDetails(ThisObject);
	
EndProcedure

#EndRegion

#Region UnprocessedDuplicatesTableEventHandlers

&AtClient
Procedure UnprocessedDuplicatesOnActivateRow(Item)
	
	AttachIdleHandler("UnprocessedDuplicateRowActivationDeferredHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UnprocessedDuplicateRowActivationDeferredHandler()
	
	RowData = Items.UnprocessedDuplicates.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	UpdateUnprocessedItemsUsageInstancesDuplicates( RowData.GetID() );
EndProcedure

&AtServer
Procedure UpdateUnprocessedItemsUsageInstancesDuplicates(Val DataString)
	RowData = UnprocessedDuplicates.FindByID(DataString);
	
	If RowData.GetParent() = Undefined Then
		// Group details
		UnprocessedItemsUsageInstances.Clear();
		
		Items.CurrentDuplicatesGroupDetails1.Title = NStr("ru = 'Для просмотра причин выберите проблемный элемент-дубль.'; en = 'To view the reasons, select the problematic duplicate item.'; pl = 'Aby wyświetlić przyczyny wybierz problematyczny element-duplikat.';es_ES = 'Para ver las causas seleccione un elemento-duplicado con problemas.';es_CO = 'Para ver las causas seleccione un elemento-duplicado con problemas.';tr = 'Nedeni görüntülemek için sorunlu nesne-kopyayı seçin.';it = 'Per vedere i motivi, seleziona l''elemento duplicato con problemi.';de = 'Um die Gründe anzuzeigen, wählen Sie das problematische Element-Duplikat.'");
		Items.UnprocessedItemsUsageInstancesPages.CurrentPage = Items.UnprocessedItemsGroupDetails;
		Return;
	EndIf;
	
	// List of error instances
	ErrorTable = GetFromTempStorage(ReplacementResultAddress);
	Filter = New Structure("Ref", RowData.Ref);
	
	Data = ErrorTable.Copy( ErrorTable.FindRows(Filter) );
	Data.Columns.Add("Icon");
	Data.FillValues(True, "Icon");
	UnprocessedItemsUsageInstances.Load(Data);
	
	If RowData.Count = 0 Then
		Items.CurrentDuplicatesGroupDetails1.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Замена дубля ""%1"" возможна, но была отменена из-за невозможности замены в других местах.'; en = 'The duplicate item ""%1"" can be replaced, but replacement was canceled because it cannot be done in other instances.'; pl = 'Wymiana duplikatu ""%1"" jest możliwe, ale została odwołana z powodu braku możliwości wymiany w innych miejscach.';es_ES = 'El cambio del duplicado ""%1"" es posible pero a causa de la imposibilidad de reemplazar en otros lugares.';es_CO = 'El cambio del duplicado ""%1"" es posible pero a causa de la imposibilidad de reemplazar en otros lugares.';tr = '""%1"" kopyanın yer değişmesi mümkün, ancak diğer yerlerde mümkün olmadığından iptal edildi.';it = 'L''elemento duplicato ""%1"" può essere sostituito, ma la sostituzione è stata annullata perché non può essere fatta in altre copie.';de = 'Das Ersetzen des Duplikats ""%1"" ist möglich, wurde aber wegen der Unmöglichkeit, an anderer Stelle zu ersetzen, abgebrochen.'"), 
			RowData.Description);
		
		Items.UnprocessedItemsUsageInstancesPages.CurrentPage = Items.UnprocessedItemsGroupDetails;
	Else
		Items.ProbableDuplicateUsageInstances.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось заменить дубли в некоторых местах (%1)'; en = 'Duplicates cannot be replaced in some usage instances (%1)'; pl = 'Nie można zastąpić duplikatów w niektórych lokalizacjach (%1)';es_ES = 'No se puede reemplazar los duplicados en algunas ubcaciones (%1)';es_CO = 'No se puede reemplazar los duplicados en algunas ubcaciones (%1)';tr = 'Bazı konumlarda çiftler değiştirilemiyor (%1)';it = 'I duplicati non possono essere sostituiti in alcune istanze di uso (%1)';de = 'Duplikate können an einigen Stellen nicht ersetzt werden (%1)'"), 
			RowData.Count);
		
		Items.UnprocessedItemsUsageInstancesPages.CurrentPage = Items.UnprocessedItemsUsageInstanceDetails;
	EndIf;
	
EndProcedure

&AtClient
Procedure UnprocessedDuplicatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenDouplicateForm(Items.UnprocessedDuplicates.CurrentData);
	
EndProcedure

#EndRegion

#Region UnprocessedItemsUsageInstancesTableEventHandlers

&AtClient
Procedure UnprocessedItemsUsageInstancesOnActivateRow(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		UnprocessedItemsErrorDescription = "";
	Else
		UnprocessedItemsErrorDescription = CurrentData.ErrorText;
	EndIf;
	
EndProcedure

&AtClient
Procedure UnprocessedsItemUsageInstancesSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = UnprocessedItemsUsageInstances.FindByID(RowSelected);
	ShowValue(, CurrentData.ErrorObject);
	
EndProcedure

#EndRegion

#Region CandidateUsageInstancesTableEventHandlers

&AtClient
Procedure CandidateUsageInstancesSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = ProbableDuplicateUsageInstances.FindByID(RowSelected);
	ShowValue(, CurrentData.Data);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WizardButtonHandler(Command)
	
	If Command.Name = WizardSettings.NextButton Then
		
		WizardStepNext();
		
	ElsIf Command.Name = WizardSettings.BackButton Then
		
		WizardStepBack();
		
	ElsIf Command.Name = WizardSettings.CancelButton Then
		
		WizardStepCancel();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectMainItem(Command)
	
	RowData = Items.FoundDuplicates.CurrentData;
	If RowData = Undefined Or RowData.Main Then
		Return; // No data or Current item is a main one already.
	EndIf;
		
	Parent = RowData.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ChangeMainItemHierarchically(RowData, Parent);
EndProcedure

&AtClient
Procedure OpenProbableDuplicate(Command)
	
	OpenDouplicateForm(Items.FoundDuplicates.CurrentData);
	
EndProcedure

&AtClient
Procedure OpenUnprocessedDuplicate(Command)
	
	OpenDouplicateForm(Items.UnprocessedDuplicates.CurrentData);
	
EndProcedure

&AtClient
Procedure ExpandDuplicatesGroups(Command)
	
	ExpandDuplicateGroupHierarchically();
	
EndProcedure

&AtClient
Procedure CollapseDuplicatesGroups(Command)
	
	CollapseDuplicateGroupHierarchically();
	
EndProcedure

&AtClient
Procedure RetrySearch(Command)
	
	GoToWizardStep(Items.PerformSearchStep);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Wizard programming interface

// Initializes wizard structures.
// The following value is written to the StepByStepWizardSettings form attribute:
//   Structure - description of wizard settings.
//     Public wizard settings:
//       * Steps - Array - description of wizard steps. Read only.
//           To add steps, use the AddWizardStep function.
//       * CurrentStep - Structure - current wizard step. Read only.
//       * ShowDialogBeforeClose - Boolean - If True, a warning will be displayed before closing the form.
//           For changing.
//     Internal wizard settings:
//       * PageGroup - String - a form item name that is passed to the PageGroup parameter.
//       * NextButton - String - a form item name that is passed to the NextButton parameter.
//       * BackButton - String - a form item name that is passed to the BackButton parameter.
//       * CancelButton - String - a form item name that is passed to the CancelButton parameter.
//
&AtServer
Procedure InitializeStepByStepWizardSettings()
	WizardSettings = New Structure;
	WizardSettings.Insert("Steps", New Array);
	WizardSettings.Insert("CurrentStep", Undefined);
	
	// Interface part IDs.
	WizardSettings.Insert("PageGroup", Items.WizardSteps.Name);
	WizardSettings.Insert("NextButton",   Items.WizardStepNext.Name);
	WizardSettings.Insert("BackButton",   Items.WizardStepBack.Name);
	WizardSettings.Insert("CancelButton",  Items.WizardStepCancel.Name);
	
	// For processing time-consuming operations.
	WizardSettings.Insert("ShowDialogBeforeClose", False);
	
	// Everything is disabled by default.
	Items.WizardStepNext.Visible  = False;
	Items.WizardStepBack.Visible  = False;
	Items.WizardStepCancel.Visible = False;
EndProcedure

// Adds a wizard step. Navigation between pages is performed according to the order the pages are added.
//
// Parameters:
//   Page - FormGroup - a page that contains step items.
//
// Returns:
//   Structure - description of page settings.
//       * PageName - String - a page name.
//       * NextButton - Structure - description of "Next" button.
//           ** Title - String - button title. The default value is "Next >".
//           ** Tooltip - String - button tooltip. Corresponds to the button title by default.
//           ** Visible - Boolean - If True, the button is visible. The default value is True.
//           ** Availability - Boolean - If True, the button is clickable. The default value is True.
//           ** DefaultButton - Boolean - if True, the button is the main button of the form. The default value is True.
//       * BackButton - Structure - description of the "Back" button.
//           ** Title - String - button title. Default value: "< Back".
//           ** Tooltip - String - button tooltip. Corresponds to the button title by default.
//           ** Visible - Boolean - If True, the button is visible. The default value is True.
//           ** Availability - Boolean - If True, the button is clickable. The default value is True.
//           ** DefaultButton - Boolean - if True, the button is the main button of the form. Default value: False.
//       * CancelButton - Structure - description of the "Cancel" button.
//           ** Title - String - button title. The default value is "Cancel".
//           ** Tooltip - String - button tooltip. Corresponds to the button title by default.
//           ** Visible - Boolean - If True, the button is visible. The default value is True.
//           ** Availability - Boolean - If True, the button is clickable. The default value is True.
//           ** DefaultButton - Boolean - if True, the button is the main button of the form. Default value: False.
//
&AtServer
Function AddWizardStep(Val Page)
	StepDescription = New Structure("IndexOf, PageName, BackButton, NextButton, CancelButton");
	StepDescription.PageName = Page.Name;
	StepDescription.BackButton = WizardButton();
	StepDescription.BackButton.Title = NStr("ru='< Назад'; en = '< Back'; pl = '< Powrót';es_ES = '< Atrás';es_CO = '< Atrás';tr = '< Geri';it = '< Indietro ';de = '< Zurück'");
	StepDescription.NextButton = WizardButton();
	StepDescription.NextButton.DefaultButton = True;
	StepDescription.NextButton.Title = NStr("ru = 'Далее >'; en = 'Next >'; pl = 'Dalej >';es_ES = 'Siguiente >';es_CO = 'Siguiente >';tr = 'Sonraki >';it = 'Avanti >';de = 'Weiter >'");
	StepDescription.CancelButton = WizardButton();
	StepDescription.CancelButton.Title = NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'");
	
	WizardSettings.Steps.Add(StepDescription);
	
	StepDescription.IndexOf = WizardSettings.Steps.UBound();
	Return StepDescription;
EndFunction

// Updates visibility and availability of form items according to the current wizard step.
&AtClientAtServerNoContext
Procedure VisibleEnabled(Form)
	
	Items = Form.Items;
	WizardSettings = Form.WizardSettings;
	CurrentStep = WizardSettings.CurrentStep;
	
	// Navigating to the page.
	Items[WizardSettings.PageGroup].CurrentPage = Items[CurrentStep.PageName];
	
	// Updating buttons.
	UpdateWizardButtonProperties(Items[WizardSettings.NextButton],  CurrentStep.NextButton);
	UpdateWizardButtonProperties(Items[WizardSettings.BackButton],  CurrentStep.BackButton);
	UpdateWizardButtonProperties(Items[WizardSettings.CancelButton], CurrentStep.CancelButton);
	
EndProcedure

// Navigates to the specified page.
//
// Parameters:
//   StepOrIndexOrFormGroup - Structure, Number, FormGroup - a page to navigate to.
//
&AtClient
Procedure GoToWizardStep(Val StepOrIndexOrFormGroup)
	
	// Searching for step.
	Type = TypeOf(StepOrIndexOrFormGroup);
	If Type = Type("Structure") Then
		StepDescription = StepOrIndexOrFormGroup;
	ElsIf Type = Type("Number") Then
		StepIndex = StepOrIndexOrFormGroup;
		If StepIndex < 0 Then
			Raise NStr("ru='Попытка выхода назад из первого шага мастера'; en = 'Attempt of going back from the first wizard step'; pl = 'Próba wyjścia do tyłu, z pierwszego kroku kreatora';es_ES = 'Intentando volver desde el primer paso del asistente';es_CO = 'Intentando volver desde el primer paso del asistente';tr = 'İlk sihirbaz adımını aşma girişimi';it = 'Tentativo di andare indietro dal primo passaggio dell''assistente guidato';de = 'Versuch, vom ersten Schritt des Assistenten zurückzukehren'");
		ElsIf StepIndex > WizardSettings.Steps.UBound() Then
			Raise NStr("ru='Попытка выхода за последний шаг мастера'; en = 'Attempt of moving forward the last wizard step'; pl = 'Próba wyjścia za ostatni krok kreatora';es_ES = 'Intentando repasar el último paso del asistente';es_CO = 'Intentando repasar el último paso del asistente';tr = 'Son sihirbaz adımını aşma girişimi';it = 'Tentativo di andare avanti all''ultimo passaggio dell''assistente guidato';de = 'Versuch, den letzten Schritt des Assistenten zu durchlaufen'");
		EndIf;
		StepDescription = WizardSettings.Steps[StepIndex];
	Else
		StepFound = False;
		RequiredPageName = StepOrIndexOrFormGroup.Name;
		For Each StepDescription In WizardSettings.Steps Do
			If StepDescription.PageName = RequiredPageName Then
				StepFound = True;
				Break;
			EndIf;
		EndDo;
		If Not StepFound Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не найден шаг ""%1"".'; en = 'Step ""%1"" is not found.'; pl = 'Krok ""%1"" nie został znaleziony.';es_ES = 'El paso ""%1"" no se ha encontrado.';es_CO = 'El paso ""%1"" no se ha encontrado.';tr = 'Adım ""%1"" bulunamadı.';it = 'Passaggio ""%1"" non trovato.';de = 'Schritt ""%1"" wird nicht gefunden.'"),
				RequiredPageName);
		EndIf;
	EndIf;
	
	// Step switch.
	WizardSettings.CurrentStep = StepDescription;
	
	// Updating visibility.
	VisibleEnabled(ThisObject);
	OnActivateWizardStep();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wizard events

&AtClient
Procedure OnActivateWizardStep()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.NoSearchPerformedStep Then
		
		Items.Header.Enabled = True;
		
		// Filter rules presentation.
		FilterRulesPresentation = String(PrefilterComposer.Settings.Filter);
		If IsBlankString(FilterRulesPresentation) Then
			FilterRulesPresentation = NStr("ru = 'Все элементы'; en = 'All items'; pl = 'Wszystkie elementy';es_ES = 'Todos los artículos';es_CO = 'Todos los artículos';tr = 'Tüm öğeler';it = 'Tutti gli elementi';de = 'Alle Elemente'");
		EndIf;
		
		// Search rules presentation.
		Conjunction = " " + NStr("ru = 'И'; en = 'AND'; pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'VE';it = 'E';de = 'UND'") + " ";
		RuleText = "";
		For Each Rule In SearchRules Do
			If Rule.Rule = "Equal" Then
				Comparison = Rule.AttributePresentation + " " + NStr("ru = 'совпадает'; en = 'matches'; pl = 'pokrywa się';es_ES = 'corresponde';es_CO = 'corresponde';tr = 'uyumlu';it = 'corrisponde';de = 'stimmt überein'");
			ElsIf Rule.Rule = "Like" Then
				Comparison = Rule.AttributePresentation + " " + NStr("ru = 'совпадает по похожим словам'; en = 'matches by similar words'; pl = 'pokrywa się według podobnych wyrazów';es_ES = 'corresponde por palabras relacionadas';es_CO = 'corresponde por palabras relacionadas';tr = 'benzer kelimelere göre uyumlu';it = 'corrispondenza per parole simili';de = 'stimmt mit ähnlichen Wörtern überein'");
			Else
				Continue;
			EndIf;
			RuleText = ?(RuleText = "", "", RuleText + Conjunction) + Comparison;
		EndDo;
		If TakeAppliedRulesIntoAccount Then
			For Position = 1 To StrLineCount(AppliedRuleDetails) Do
				RuleRow = TrimAll(StrGetLine(AppliedRuleDetails, Position));
				If Not IsBlankString(RuleRow) Then
					RuleText = ?(RuleText = "", "", RuleText + Conjunction) + RuleRow;
				EndIf;
			EndDo;
		EndIf;
		If IsBlankString(RuleText) Then
			RuleText = NStr("ru = 'Правила не заданы'; en = 'Rules not set'; pl = 'Reguły nie są ustawione';es_ES = 'Las reglas no se han establecido';es_CO = 'Las reglas no se han establecido';tr = 'Kurallar belirlenmedi';it = 'Regole non impostate';de = 'Die Regeln sind nicht festgelegt'");
		EndIf;
		SearchRulesPresentation = RuleText;
		
		// Enabled.
		Items.FilterRulesPresentation.Enabled = Not IsBlankString(DuplicatesSearchArea);
		Items.SearchRulesPresentation.Enabled = Not IsBlankString(DuplicatesSearchArea);
		
	ElsIf CurrentPage = Items.PerformSearchStep Then
		
		If Not IsTempStorageURL(CompositionSchemaAddress) Then
			Return; // Not initialized.
		EndIf;
		Items.Header.Enabled = False;
		WizardSettings.ShowDialogBeforeClose = True;
		RunBackgroundJobClient();
		
	ElsIf CurrentPage = Items.MainItemSelectionStep Then
		
		Items.Header.Enabled = True;
		Items.RetrySearch.Visible = True;
		ExpandDuplicateGroupHierarchically();
		
	ElsIf CurrentPage = Items.DeletionStep Then
		
		Items.Header.Enabled = False;
		WizardSettings.ShowDialogBeforeClose = True;
		RunBackgroundJobClient();
		
	ElsIf CurrentPage = Items.SuccessfulDeletionStep Then
		
		Items.Header.Enabled = False;
		
	ElsIf CurrentPage = Items.UnsuccessfulReplacementsStep Then
		
		Items.Header.Enabled = False;
		
	ElsIf CurrentPage = Items.DuplicatesNotFoundStep Then
		
		Items.Header.Enabled = True;
		
	ElsIf CurrentPage = Items.ErrorOccurredStep Then
		
		Items.Header.Enabled = True;
		Items.DetailsRef.Visible = ValueIsFilled(Items.DetailsRef.ToolTip);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepNext()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.NoSearchPerformedStep Then
		
		If IsBlankString(DuplicatesSearchArea) Then
			ShowMessageBox(, NStr("ru = 'Необходимо выбрать область поиска дублей'; en = 'Select an area to search for duplicates'; pl = 'Wybierz obszar do wyszukiwania duplikatów';es_ES = 'Seleccionar un área para buscar los duplicados';es_CO = 'Seleccionar un área para buscar los duplicados';tr = 'Kopyaları aramak için alan seçin';it = 'Selezionare una area di ricerca per duplicati';de = 'Wählen Sie den Bereich, um nach Duplikaten zu suchen'"));
			Return;
		EndIf;
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	ElsIf CurrentPage = Items.MainItemSelectionStep Then
		
		Items.RetrySearch.Visible = False;
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	ElsIf CurrentPage = Items.UnsuccessfulReplacementsStep Then
		
		GoToWizardStep(Items.DeletionStep);
		
	ElsIf CurrentPage = Items.DuplicatesNotFoundStep Then
		
		GoToWizardStep(Items.PerformSearchStep);
		
	Else
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepBack()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.SuccessfulDeletionStep Then
		
		GoToWizardStep(Items.NoSearchPerformedStep);
		
	Else
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf - 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepCancel()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.PerformSearchStep
		Or CurrentPage = Items.DeletionStep Then
		
		WizardSettings.ShowDialogBeforeClose = False;
		
	EndIf;
	
	If IsOpen() Then
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Function FullFormName(ShortFormName)
	Names = StrSplit(FormName, ".");
	Return Names[0] + "." + Names[1] + ".Form." + ShortFormName;
EndFunction

&AtClient
Procedure OpenDouplicateForm(Val CurrentData)
	If CurrentData = Undefined Or Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
	
	ShowValue(,CurrentData.Ref);
EndProcedure

&AtClient
Procedure ShowUsageInstances(SourceTree)
	RefsArray = New Array;
	For Each DuplicateGroup In SourceTree.GetItems() Do
		For Each TreeRow In DuplicateGroup.GetItems() Do
			RefsArray.Add(TreeRow.Ref);
		EndDo;
	EndDo;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Filter", New Structure("RefSet", RefsArray));
	WindowMode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm("Report.SearchForReferences.Form", ReportParameters, ThisObject, , , , , WindowMode);
EndProcedure

&AtClient
Procedure ExpandDuplicateGroupHierarchically(Val DataString = Undefined)
	If DataString <> Undefined Then
		Items.FoundDuplicates.Expand(DataString, True);
	EndIf;
	
	// All of the first level
	AllRows = Items.FoundDuplicates;
	For Each RowData In FoundDuplicates.GetItems() Do 
		AllRows.Expand(RowData.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure CollapseDuplicateGroupHierarchically(Val DataString = Undefined)
	If DataString <> Undefined Then
		Items.FoundDuplicates.Collapse(DataString);
		Return;
	EndIf;
	
	// All of the first level
	AllRows = Items.FoundDuplicates;
	For Each RowData In FoundDuplicates.GetItems() Do 
		AllRows.Collapse(RowData.GetID());
	EndDo;
EndProcedure

&AtClient
Procedure ChangeCandidateMarksHierarchically(Val RowData)
	SetMarksForChilds(RowData);
	SetMarksForParents(RowData);
EndProcedure

&AtClient
Procedure SetMarksForChilds(Val RowData)
	Value = RowData.Check;
	For Each Child In RowData.GetItems() Do
		Child.Check = Value;
		SetMarksForChilds(Child);
	EndDo;
EndProcedure

&AtClient
Procedure SetMarksForParents(Val RowData)
	RowParent = RowData.GetParent();
	
	If RowParent <> Undefined Then
		AllTrue = True;
		NotAllFalse = False;
		
		For Each Child In RowParent.GetItems() Do
			AllTrue = AllTrue AND (Child.Check = 1);
			NotAllFalse = NotAllFalse Or (Child.Check > 0);
		EndDo;
		
		If AllTrue Then
			RowParent.Check = 1;
			
		ElsIf NotAllFalse Then
			RowParent.Check = 2;
			
		Else
			RowParent.Check = 0;
			
		EndIf;
		
		SetMarksForParents(RowParent);
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateFoundDuplicatesNumber()
	TotalFoundDuplicates = 0;
	For Each Duplicate In FoundDuplicates.GetItems() Do
		For Each Child In Duplicate.GetItems() Do
			If Not Child.Main AND Child.Check Then
				TotalFoundDuplicates = TotalFoundDuplicates + 1;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure ChangeMainItemHierarchically(Val RowData, Val Parent)
	For Each Child In Parent.GetItems() Do
		Child.Main = False;
	EndDo;
	RowData.Main = True;
	
	// Selected item is used always.
	RowData.Check = 1;
	ChangeCandidateMarksHierarchically(RowData);
	
	// Changing the group name
	Parent.Description = RowData.Description + " (" + Parent.Count + ")";
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client, Server

&AtClientAtServerNoContext
Procedure UpdateFoundDuplicatesStateDetails(Form)
	
	Form.FoundDuplicatesStateDetails = New FormattedString(
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Найдено дублей: %2 (среди элементов: %1). Все отмеченные элементы будут помечены на удаление и заменены во всех местах использования на оригиналы (отмечены стрелкой).'; en = 'Found duplicates: %2 (among items: %1). All selected items will be marked for deletion and replaced in all usage instances with the original ones (marked with an arrow).'; pl = 'Znaleziono duplikatów: %2 (wśród elementów: %1). Wszystkie zaznaczone elementy zostaną oznaczone na usuwanie i zastąpione we wszystkich miejscach korzystania na oryginały (oznaczone strzałką).';es_ES = 'Duplicados se han encontrado: %2 (entre elementos: %1). Todos los artículos seleccionado se marcarán para borrar y se sustituirán por los originales en todos los sitios de uso (marcados con una flecha).';es_CO = 'Duplicados se han encontrado: %2 (entre elementos: %1). Todos los artículos seleccionado se marcarán para borrar y se sustituirán por los originales en todos los sitios de uso (marcados con una flecha).';tr = 'Öğelerin kopyaları bulundu: %1 (öğeler arasında:%2). Seçilen tüm öğeler silinmek üzere işaretlenecek ve tüm kullanım yerlerinde (okla işaretlenmiş) orijinaller ile değiştirilecektir.';it = 'Trovati duplicati: %2 (tra gli elementi: %1). Tutti gli elementi selezionati saranno contrassegnati per l''eliminazione e sostituiti in tutte le istanze di uso con gli originali (contrassegnati con una freccia).';de = 'Es wurde ein Duplikat gefunden: %2(unter den Elementen: %1). Alle markierten Elemente werden zum Löschen markiert und an allen Verwendungsorten durch Originale ersetzt (mit einem Pfeil markiert).'"),
			Form.TotalItems,
			Form.TotalFoundDuplicates),
		,
		Form.InformationTextColor);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call, Server

&AtServer
Function FilterComposerSettingsAddress()
	Return PutToTempStorage(PrefilterComposer.Settings, UUID);
EndFunction

&AtServer
Function SearchRuleSettingsAddress()
	Settings = New Structure;
	Settings.Insert("TakeAppliedRulesIntoAccount", TakeAppliedRulesIntoAccount);
	Settings.Insert("AllComparisonOptions", AllComparisonOptions);
	Settings.Insert("SearchRules", FormAttributeToValue("SearchRules"));
	Return PutToTempStorage(Settings);
EndFunction

&AtServer
Procedure UpdateFilterComposer(ResultAddress)
	Result = GetFromTempStorage(ResultAddress);
	DeleteFromTempStorage(ResultAddress);
	PrefilterComposer.LoadSettings(Result);
	PrefilterComposer.Refresh(DataCompositionSettingsRefreshMethod.Full);
	SaveUserSettingsSSL();
EndProcedure

&AtServer
Procedure UpdateSearchRules(ResultAddress)
	Result = GetFromTempStorage(ResultAddress);
	DeleteFromTempStorage(ResultAddress);
	TakeAppliedRulesIntoAccount = Result.TakeAppliedRulesIntoAccount;
	ValueToFormAttribute(Result.SearchRules, "SearchRules");
	SaveUserSettingsSSL();
EndProcedure

&AtServer
Procedure InitFilterComposerAndRules(FormSettings)
	// 1. Clearing and initialization info of the metadata object.
	FilterRulesPresentation = "";
	SearchRulesPresentation = "";
	
	SettingsTable = GetFromTempStorage(SettingsAddress);
	SettingsTableRow = SettingsTable.Find(DuplicatesSearchArea, "FullName");
	If SettingsTableRow = Undefined Then
		DuplicatesSearchArea = "";
		Return;
	EndIf;
	
	MetadataObject = Metadata.FindByFullName(DuplicatesSearchArea);
	
	// 2. DCS initialization used to filter.
	CompositionSchema = New DataCompositionSchema;
	DataSource = CompositionSchema.DataSources.Add();
	DataSource.DataSourceType = "Local";
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = "SELECT " + AvailableFilterAttributes(MetadataObject) + " FROM " + DuplicatesSearchArea;
	DataSet.AutoFillAvailableFields = True;
	
	CompositionSchemaAddress = PutToTempStorage(CompositionSchema, UUID);
	
	PrefilterComposer.Initialize(New DataCompositionAvailableSettingsSource(CompositionSchema));
	
	// 3. Filling the SearchRules table.
	RulesTable = FormAttributeToValue("SearchRules");
	RulesTable.Clear();
	
	IgnoredAttributes = New Structure("DeletionMark, Ref, Predefined, PredefinedDataName, IsFolder");
	AddMetaAttributeRules(RulesTable, IgnoredAttributes, AllComparisonOptions, MetadataObject.StandardAttributes, FuzzySearch);
	AddMetaAttributeRules(RulesTable, IgnoredAttributes, AllComparisonOptions, MetadataObject.Attributes, FuzzySearch);
	
	// 4. Import saved values.
	FiltersAreImported = False;
	DCSettings = CommonClientServer.StructureProperty(FormSettings, "DCSettings");
	If TypeOf(DCSettings) = Type("DataCompositionSettings") Then
		PrefilterComposer.LoadSettings(DCSettings);
		FiltersAreImported = True;
	EndIf;
	
	RulesAreImported = False;
	SavedRules = CommonClientServer.StructureProperty(FormSettings, "SearchRules");
	If TypeOf(SavedRules) = Type("ValueTable") Then
		RulesAreImported = True;
		For Each SavedRule In SavedRules Do
			Rule = RulesTable.Find(SavedRule.Attribute, "Attribute");
			If Rule <> Undefined
				AND Rule.ComparisonOptions.FindByValue(SavedRule.Rule) <> Undefined Then
				Rule.Rule = SavedRule.Rule;
			EndIf;
		EndDo;
	EndIf;
	
	// 5. Setting the default parameters.
	// Filter by deletion mark.
	If Not FiltersAreImported Then
		CommonClientServer.SetFilterItem(
			PrefilterComposer.Settings.Filter,
			"DeletionMark",
			False,
			DataCompositionComparisonType.Equal,
			,
			False);
	EndIf;
	// Comparison by description.
	If Not RulesAreImported Then
		Rule = RulesTable.Find("Description", "Attribute");
		If Rule <> Undefined Then
			ValueForComparison = ?(FuzzySearch, "Like", "Equal");
			If Rule.ComparisonOptions.FindByValue(ValueForComparison) <> Undefined Then
				Rule.Rule = ValueForComparison;
			EndIf;
		EndIf;
	EndIf;
	
	// 6. Extensions in the applied rules.
	AppliedRuleDetails = Undefined;
	If SettingsTableRow.EventDuplicateSearchParameters Then
		DefaultParameters = New Structure;
		DefaultParameters.Insert("SearchRules",        RulesTable);
		DefaultParameters.Insert("CompareRestrictions", New Array);
		DefaultParameters.Insert("FilterComposer",    PrefilterComposer);
		DefaultParameters.Insert("ItemCountToCompare", 1000);
		MetadataObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		MetadataObjectManager.DuplicatesSearchParameters(DefaultParameters);
		
		// Presentation of applied rules.
		AppliedRuleDetails = "";
		For Each Details In DefaultParameters.CompareRestrictions Do
			AppliedRuleDetails = AppliedRuleDetails + Chars.LF + Details.Presentation;
		EndDo;
		AppliedRuleDetails = TrimAll(AppliedRuleDetails);
	EndIf;
	
	PrefilterComposer.Refresh(DataCompositionSettingsRefreshMethod.Full);
	
	RulesTable.Sort("AttributePresentation");
	ValueToFormAttribute(RulesTable, "SearchRules");
	
	If FormSettings = Undefined Then
		SaveUserSettingsSSL();
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure OnCreateAtServerDataInitialization(FormSettings)
	TakeAppliedRulesIntoAccount = CommonClientServer.StructureProperty(FormSettings, "TakeAppliedRulesIntoAccount");
	DuplicatesSearchArea        = CommonClientServer.StructureProperty(FormSettings, "DuplicatesSearchArea");
	
	SettingsTable = DuplicateObjectDetection.MetadataObjectsSettings();
	SettingsAddress = PutToTempStorage(SettingsTable, UUID);
	
	ChoiceList = Items.DuplicatesSearchArea.ChoiceList;
	For Each TableRow In SettingsTable Do
		ChoiceList.Add(TableRow.FullName, TableRow.ListPresentation, , PictureLib[TableRow.Kind]);
	EndDo;
	
	AllComparisonOptions.Add("Equal",   NStr("ru = 'Совпадает'; en = 'Matches'; pl = 'Pasuje do';es_ES = 'Corresponde';es_CO = 'Corresponde';tr = 'Uyumlu';it = 'Corrisponde';de = 'Übereinstimmen'"));
	AllComparisonOptions.Add("Like", NStr("ru = 'Совпадает по похожим словам'; en = 'Matches by similar words'; pl = 'Dopasowano według podobnych słów';es_ES = 'Corresponde por palabras relacionadas';es_CO = 'Corresponde por palabras relacionadas';tr = 'Benzer kelimelere göre uyumlu';it = 'Corrispondenza per parole simili';de = 'Stimmt mit ähnlichen wörtern überein'"));
EndProcedure

&AtServer
Procedure SaveUserSettingsSSL()
	FormSettings = New Structure;
	FormSettings.Insert("TakeAppliedRulesIntoAccount", TakeAppliedRulesIntoAccount);
	FormSettings.Insert("DuplicatesSearchArea", DuplicatesSearchArea);
	FormSettings.Insert("DCSettings", PrefilterComposer.Settings);
	FormSettings.Insert("SearchRules", SearchRules.Unload());
	Common.CommonSettingsStorageSave(FormName, "", FormSettings);
EndProcedure

&AtServer
Procedure SetColorsAndConditionalAppearance()
	InformationTextColor       = StyleColorOrAuto("NoteText",       69,  81,  133);
	ErrorInformationTextColor = StyleColorOrAuto("ErrorNoteText", 255, 0,   0);
	InaccessibleDataColor     = StyleColorOrAuto("InaccessibleDataColor", 192, 192, 192);
	
	ConditionalAppearanceItems = ConditionalAppearance.Items;
	ConditionalAppearanceItems.Clear();
	
	// No usage instances of the group.
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Ref");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	AppearanceFilter.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Text", "");
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesCount");
	
	// 1. Row with the current main group item:
	
	// Picture
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Main");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Visible", True);
	AppearanceItem.Appearance.SetParameterValue("Show", True);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesMain");
	
	// Mark cleared
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Main");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Visible", False);
	AppearanceItem.Appearance.SetParameterValue("Show", False);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesCheck");
	
	// 2. Row with a usual item.
	
	// Picture
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Main");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	AppearanceItem.Appearance.SetParameterValue("Visible", False);
	AppearanceItem.Appearance.SetParameterValue("Show", False);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesMain");
	
	// Mark selected
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Main");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	AppearanceItem.Appearance.SetParameterValue("Visible", True);
	AppearanceItem.Appearance.SetParameterValue("Show", True);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesCheck");
	
	// 3. Usage instances
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Ref");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Filled;
	AppearanceFilter.RightValue = True;
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Count");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = 0;
	
	AppearanceItem.Appearance.SetParameterValue("Text", NStr("ru = '-'; en = '-'; pl = '-';es_ES = '-';es_CO = '-';tr = '-';it = '-';de = '-'"));
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesCount");
	
	// 4. Inactive row
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Check");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = 0;
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", InaccessibleDataColor);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicates");
	
EndProcedure

&AtServer
Function StyleColorOrAuto(Val Name, Val R = Undefined, Green = Undefined, Blue = Undefined)
	StyleItem = Metadata.StyleItems.Find(Name);
	If StyleItem <> Undefined AND StyleItem.Type = Metadata.ObjectProperties.StyleElementType.Color Then
		Return StyleColors[Name];
	EndIf;
	
	Return ?(R = Undefined, New Color, New Color(R, Green, Blue));
EndFunction

&AtServer
Function DuplicateReplacementCouples()
	ReplacementPairs = New Map;
	
	DuplicateTree = FormAttributeToValue("FoundDuplicates");
	SearchFilter = New Structure("Main", True);
	
	For Each Parent In DuplicateTree.Rows Do
		MainInGroup = Parent.Rows.FindRows(SearchFilter)[0].Ref;
		
		For Each Child In Parent.Rows Do
			If Child.Check = 1 Then 
				ReplacementPairs.Insert(Child.Ref, MainInGroup);
			EndIf;
		EndDo;
	EndDo;
	
	Return ReplacementPairs;
EndFunction

&AtServerNoContext
Function AvailableFilterAttributes(MetadataObject)
	AttributesArray = New Array;
	For Each AttributeMetadata In MetadataObject.StandardAttributes Do
		If Not AttributeMetadata.Type.ContainsType(Type("ValueStorage")) Then
			AttributesArray.Add(AttributeMetadata.Name);
		EndIf
	EndDo;
	For Each AttributeMetadata In MetadataObject.Attributes Do
		If Not AttributeMetadata.Type.ContainsType(Type("ValueStorage")) Then
			AttributesArray.Add(AttributeMetadata.Name);
		EndIf
	EndDo;
	Return StrConcat(AttributesArray, ",");
EndFunction

&AtServerNoContext
Procedure AddMetaAttributeRules(RulesTable, Val Ignore, Val AllComparisonOptions, Val MetaCollection, Val FuzzySearchIsAvailable)
	
	For Each MetaAttribute In MetaCollection Do
		If Not Ignore.Property(MetaAttribute.Name) Then
			ComparisonOptions = ComparisonOptionsForType(MetaAttribute.Type, AllComparisonOptions, FuzzySearchIsAvailable);
			If ComparisonOptions <> Undefined Then
				// Can be compared
				RulesRow = RulesTable.Add();
				RulesRow.Attribute          = MetaAttribute.Name;
				RulesRow.ComparisonOptions = ComparisonOptions;
				
				AttributePresentation = MetaAttribute.Synonym;
				RulesRow.AttributePresentation = ?(IsBlankString(AttributePresentation), MetaAttribute.Name, AttributePresentation);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function ComparisonOptionsForType(Val AvailableTypes, Val AllComparisonOptions, Val FuzzySearchIsAvailable) 
	
	IsStorage = AvailableTypes.ContainsType(Type("ValueStorage"));
	If IsStorage Then 
		// Cannot be compared
		Return Undefined;
	EndIf;
	
	IsString = AvailableTypes.ContainsType(Type("String"));
	IsFixedString = IsString AND AvailableTypes.StringQualifiers <> Undefined 
		AND AvailableTypes.StringQualifiers.Length <> 0;
		
	If IsString AND Not IsFixedString Then
		// Cannot be compared
		Return Undefined;
	EndIf;
	
	Result = New ValueList;
	FillPropertyValues(Result.Add(), AllComparisonOptions[0]);		// Matches
	
	If FuzzySearchIsAvailable AND IsString Then
		FillPropertyValues(Result.Add(), AllComparisonOptions[1]);	// Similar
	EndIf;
		
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Time-consuming operations

&AtClient
Procedure RunBackgroundJobClient()
	Job = RunBackgroundJob();
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("AfterCompleteBackgroundJob", ThisObject);
	
	TimeConsumingOperationsClient.WaitForCompletion(Job, Handler, WaitSettings);
EndProcedure

&AtServer
Function RunBackgroundJob()
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("TakeAppliedRulesIntoAccount", TakeAppliedRulesIntoAccount);
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.PerformSearchStep Then
		
		ProcedureName = FormAttributeToValue("Object").Metadata().FullName() + ".ObjectModule.BackgroundSearchForDuplicates";
		MethodDescription = NStr("ru = 'Поиск и удаление дублей: Поиск дублей'; en = 'Duplicates search and deletion: Search for duplicates'; pl = 'Wyszukaj i usuń duplikaty: Wyszukaj duplikaty';es_ES = 'Buscar y borrar los duplicados: Búsqueda de duplicados';es_CO = 'Buscar y borrar los duplicados: Búsqueda de duplicados';tr = 'Çiftleri ara ve sil: Çiftleri ara';it = 'Ricerca duplicati ed eliminazione: Ricerca per duplicati';de = 'Suchen und Löschen von Duplikaten: Suchen Sie nach Duplikaten'");
		ProcedureParameters.Insert("DuplicatesSearchArea",     DuplicatesSearchArea);
		ProcedureParameters.Insert("MaxDuplicates", 1500);
		SearchRuleArray = New Array;
		For Each Rule In SearchRules Do
			SearchRuleArray.Add(New Structure("Attribute, Rule", Rule.Attribute, Rule.Rule));
		EndDo;
		ProcedureParameters.Insert("SearchRules", SearchRuleArray);
		ProcedureParameters.Insert("CompositionSchema", GetFromTempStorage(CompositionSchemaAddress));
		ProcedureParameters.Insert("PrefilterComposerSettings", PrefilterComposer.Settings);
		
	ElsIf CurrentPage = Items.DeletionStep Then
		
		ProcedureName = FormAttributeToValue("Object").Metadata().FullName() + ".ObjectModule.BackgroundDuplicateDeletion";
		MethodDescription = NStr("ru = 'Поиск и удаление дублей: Удаление дублей'; en = 'Duplicates search and deletion: Delete duplicates'; pl = 'Wyszukiwanie i usuwanie duplikatów: Usuń duplikaty';es_ES = 'Buscar y borrar los duplicados: Eliminar los duplicados';es_CO = 'Buscar y borrar los duplicados: Eliminar los duplicados';tr = 'Çiftlerin aranması ve silinmesi: Çiftleri sil';it = 'Ricerca duplicati ed eliminazione: Elimina duplicati';de = 'Suchen und Löschen von Duplikaten: Löschen Sie Duplikate'");
		ProcedureParameters.Insert("DeletionMethod", "Check");
		ProcedureParameters.Insert("ReplacementPairs", DuplicateReplacementCouples());
		ProcedureParameters.Insert("ReplacePairsInTransaction", False);
		
	Else
		Raise NStr("ru = 'Некорректное имя процедуры.'; en = 'Incorrect procedure name.'; pl = 'Nieprawidłowa nazwa procedury.';es_ES = 'Nombre del procedimiento incorrecto.';es_CO = 'Nombre del procedimiento incorrecto.';tr = 'Hatalı prosedür adı.';it = 'Nome procedura non corretto.';de = 'Falscher Name der Prozedur.'");
	EndIf;
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = MethodDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, StartSettings);
EndFunction

&AtClient
Procedure AfterCompleteBackgroundJob(Job, AdditionalParameters) Export
	WizardSettings.ShowDialogBeforeClose = False;
	Activate();
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	// The job is canceled.
	If Job = Undefined Then 
		Return;
	EndIf;
	
	If Job.Status <> "Completed" Then
		// Background job is completed with error.
		If CurrentPage = Items.PerformSearchStep Then
			BriefDescription = NStr("ru = 'При поиске дублей возникла ошибка:'; en = 'An error occurred when searching for duplicates:'; pl = 'Podczas wyszukiwania duplikatów wystąpił błąd:';es_ES = 'Al buscar los duplicados ha ocurrido un error:';es_CO = 'Al buscar los duplicados ha ocurrido un error:';tr = 'Kopyaları ararken hata oluştu:';it = 'Errore durante la ricerca dei duplicati:';de = 'Bei der Suche nach Duplikaten ist ein Fehler aufgetreten:'");
		ElsIf CurrentPage = Items.DeletionStep Then
			BriefDescription = NStr("ru = 'При удалении дублей возникла ошибка:'; en = 'An error occurred when deleting duplicates:'; pl = 'Podczas usuwania duplikatów wystąpił błąd:';es_ES = 'Al eliminar los duplicados ha ocurrido un error:';es_CO = 'Al eliminar los duplicados ha ocurrido un error:';tr = 'Kopyaları silerken hata oluştu:';it = 'Errore durante l''eliminazione dei duplicati:';de = 'Beim Löschen von Duplikaten ist ein Fehler aufgetreten:'");
		EndIf;
		BriefDescription = BriefDescription + Chars.LF + Job.BriefErrorPresentation;
		More = BriefDescription + Chars.LF + Chars.LF + Job.DetailedErrorPresentation;
		Items.ErrorTextLabel.Title = BriefDescription;
		Items.DetailsRef.ToolTip    = More;
		GoToWizardStep(Items.ErrorOccurredStep);
		Return;
	EndIf;
	
	If CurrentPage = Items.PerformSearchStep Then
		TotalFoundDuplicates = FillDuplicateSearchResults(Job.ResultAddress);
		If TotalFoundDuplicates > 0 Then
			// Duplicates are found.
			GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		ElsIf TotalFoundDuplicates < 0 Then
			// An error occurred (probably too many duplicates were found).
			GoToWizardStep(Items.ErrorOccurredStep);
		Else
			// No duplicates found by the current settings.
			GoToWizardStep(Items.DuplicatesNotFoundStep);
		EndIf;
	ElsIf CurrentPage = Items.DeletionStep Then
		Success = FillDuplicateDeletionResults(Job.ResultAddress);
		If Success = True Then
			// All duplicate groups are replaced.
			GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		Else
			// Not all references are replaced.
			GoToWizardStep(Items.UnsuccessfulReplacementsStep);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function FillDuplicateSearchResults(Val ResultAddress)
	// Data - DuplicateGroups module function result.
	Data = GetFromTempStorage(ResultAddress);
	If Not IsBlankString(Data.ErrorDescription) Then // Background job crashed
		Items.ErrorTextLabel.Title = Data.ErrorDescription;
		Items.DetailsRef.Visible    = False;
		Return -1;
	EndIf;
	
	// No search errors
	// Creating a tree for editing by the result tables.
	TreeItems = FoundDuplicates.GetItems();
	TreeItems.Clear();
	
	UsageInstances = Data.UsageInstances;
	DuplicatesTable      = Data.DuplicatesTable;
	
	RowFilter = New Structure("Parent");
	InstanceFilter  = New Structure("Ref");
	
	TotalFoundDuplicates = 0;
	
	AllGroups = DuplicatesTable.FindRows(RowFilter);
	For Each Folder In AllGroups Do
		RowFilter.Parent = Folder.Ref;
		GroupItems = DuplicatesTable.FindRows(RowFilter);
		
		TreeGroup = TreeItems.Add();
		TreeGroup.Count = GroupItems.Count();
		TreeGroup.Check = 1;
		
		MaxRow = Undefined;
		MaxInstances   = -1;
		For Each Item In GroupItems Do
			TreeRow = TreeGroup.GetItems().Add();
			FillPropertyValues(TreeRow, Item, "Ref, Code, Description");
			TreeRow.Check = 1;
			
			InstanceFilter.Ref = Item.Ref;
			TreeRow.Count = UsageInstances.FindRows(InstanceFilter).Count();
			
			If MaxInstances < TreeRow.Count Then
				If MaxRow <> Undefined Then
					MaxRow.Main = False;
				EndIf;
				MaxRow = TreeRow;
				MaxInstances   = TreeRow.Count;
				MaxRow.Main = True;
			EndIf;
			
			TotalFoundDuplicates = TotalFoundDuplicates + 1;
		EndDo;
		
		// Setting the candidate by the maximum reference.
		TreeGroup.Description = MaxRow.Description + " (" + TreeGroup.Count + ")";
	EndDo;
	
	// Saving the usage instances for further filtering.
	ProbableDuplicateUsageInstances.Clear();
	Items.CurrentDuplicatesGroupDetails.Title = NStr("ru = 'Дублей не найдено'; en = 'No duplicates found'; pl = 'Duplikatów nie znaleziono';es_ES = 'Duplicados no se han encontrado';es_CO = 'Duplicados no se han encontrado';tr = 'Çiftler bulunamadı';it = 'Nessun duplicato trovato';de = 'Duplikate werden nicht gefunden'");
	
	If IsTempStorageURL(UsageInstancesAddress) Then
		DeleteFromTempStorage(UsageInstancesAddress);
	EndIf;
	UsageInstancesAddress = PutToTempStorage(UsageInstances, UUID);
	
	If TotalFoundDuplicates = TreeItems.Count() Then
		FoundDuplicatesStateDetails = New FormattedString(Items.Information16.Picture, " ",
			NStr("ru = 'Не обнаружено дублей по указанным условиям.'; en = 'No duplicates found by the specified criteria.'; pl = 'Nie stwierdzono duplikatów według określonych kryterium.';es_ES = 'Duplicados no se han encontrado según las condiciones especificadas.';es_CO = 'Duplicados no se han encontrado según las condiciones especificadas.';tr = 'Belirtilen şartlara göre kopyalar bulunamadı';it = 'Nessun duplicato trovato secondo il criterio specificato.';de = 'Unter den angegebenen Bedingungen wurden keine Duplikate gefunden.'"));
	Else
		UpdateFoundDuplicatesStateDetails(ThisObject);
	EndIf;
	
	Return TotalFoundDuplicates;
EndFunction

&AtServer
Function FillDuplicateDeletionResults(Val ResultAddress)
	// ErrorTable - ReplaceReferences module function result.
	ErrorTable = GetFromTempStorage(ResultAddress);
	
	If IsTempStorageURL(ReplacementResultAddress) Then
		DeleteFromTempStorage(ReplacementResultAddress);
	EndIf;
	
	CompletedWithoutErrors = ErrorTable.Count() = 0;
	LastCandidate  = Undefined;
	
	If CompletedWithoutErrors Then
		ProcessedItemsTotal = 0; 
		MainItemsTotal   = 0;
		For Each DuplicateGroup In FoundDuplicates.GetItems() Do
			If DuplicateGroup.Check Then
				For Each Candidate In DuplicateGroup.GetItems() Do
					If Candidate.Main Then
						LastCandidate = Candidate.Ref;
						ProcessedItemsTotal   = ProcessedItemsTotal + 1;
						MainItemsTotal     = MainItemsTotal + 1;
					ElsIf Candidate.Check Then 
						ProcessedItemsTotal = ProcessedItemsTotal + 1;
					EndIf;
				EndDo;
			EndIf;
		EndDo;
		
		If MainItemsTotal = 1 Then
			// Multiple duplicates to the one item.
			If LastCandidate = Undefined Then
				FoundDuplicatesStateDetails = New FormattedString(
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Все найденные дубли (%1) успешно объединены'; en = 'All found duplicates (%1) are merged'; pl = 'Wszystkie znalezione duplikaty (%1) zostały pomyślnie zgrupowane';es_ES = 'Todos los duplicados encontrados (%1) se han agrupado con éxito';es_CO = 'Todos los duplicados encontrados (%1) se han agrupado con éxito';tr = 'Bulunan tüm kopyalar (%1) başarıyla gruplandırıldı';it = 'Tutti i duplicati trovati (%1) sono stati uniti';de = 'Alle gefundenen Duplikate (%1) wurden erfolgreich gruppiert'"),
						ProcessedItemsTotal));
			Else
				LastCandidateLine = Common.SubjectString(LastCandidate);
				FoundDuplicatesStateDetails = New FormattedString(
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Все найденные дубли (%1) успешно объединены
							|в ""%2""'; 
							|en = 'All found duplicates (%1) are successfully merged
							|into ""%2""'; 
							|pl = 'Wszystkie znalezione duplikaty (%1) zostały pomyślnie połączone
							|w ""%2""';
							|es_ES = 'Todos los duplicados encontrados (%1) se han combinado con éxito
							|en ""%2""';
							|es_CO = 'Todos los duplicados encontrados (%1) se han combinado con éxito
							|en ""%2""';
							|tr = 'Bulunan tüm kopyalar (%1) başarıyla
							| ile %2 gruplandırıldı';
							|it = 'Tutti i duplicati trovati (%1) sono stato unificati con successo
							|in ""%2""';
							|de = 'Alle gefundenen Duplikate (%1) wurden erfolgreich zusammengeführt
							|in ""%2""'"),
						ProcessedItemsTotal, LastCandidateLine));
			EndIf;
		Else
			// Multiple duplicates to the multiple groups.
			FoundDuplicatesStateDetails = New FormattedString(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Все найденные дубли (%1) успешно объединены.
						|Оставлено элементов (%2).'; 
						|en = 'All found duplicates (%1) are successfully merged.
						|Items left (%2).'; 
						|pl = 'Wszystkie znalezione duplikaty (%1) zostały pomyślnie połączone.
						|Zatrzymano elementy (%2).';
						|es_ES = 'Todos los duplicados encontrados (%1) se han combinado con éxito.
						|Artículos guardados (%2).';
						|es_CO = 'Todos los duplicados encontrados (%1) se han combinado con éxito.
						|Artículos guardados (%2).';
						|tr = 'Bulunan tüm kopyalar (%1) başarıyla birleştirildi. 
						|Tutulan öğeler (%2).';
						|it = 'Tutti i duplicati trovati (%1) sono stato unificati con successo.
						|Elementi rimanenti (%2).';
						|de = 'Alle gefundenen Duplikate (%1) erfolgreich zusammengeführt.
						|Gehalten Elemente (%2).'"),
					ProcessedItemsTotal,
					MainItemsTotal));
		EndIf;
	EndIf;
	
	UnprocessedDuplicates.GetItems().Clear();
	UnprocessedItemsUsageInstances.Clear();
	ProbableDuplicateUsageInstances.Clear();
	
	If CompletedWithoutErrors Then
		FoundDuplicates.GetItems().Clear();
		Return True;
	EndIf;
	
	// Saving for the further access when analyzing the references.
	ReplacementResultAddress = PutToTempStorage(ErrorTable, UUID);
	
	// Generating the duplicate tree by errors.
	ValueToFormAttribute(FormAttributeToValue("FoundDuplicates"), "UnprocessedDuplicates");
	
	// Analyzing the remains
	Filter = New Structure("Ref");
	Parents = UnprocessedDuplicates.GetItems();
	ParentPosition = Parents.Count() - 1;
	While ParentPosition >= 0 Do
		Parent = Parents[ParentPosition];
		
		Children = Parent.GetItems();
		ChildPosition = Children.Count() - 1;
		MainChild = Children[0];	// There is at least one
		
		While ChildPosition >= 0 Do
			Child = Children[ChildPosition];
			
			If Child.Main Then
				MainChild = Child;
				Filter.Ref = Child.Ref;
				Child.Count = ErrorTable.FindRows(Filter).Count();
				
			ElsIf ErrorTable.Find(Child.Ref, "Ref") = Undefined Then
				// Successfully deleted, no errors.
				Children.Delete(Child);
				
			Else
				Filter.Ref = Child.Ref;
				Child.Count = ErrorTable.FindRows(Filter).Count();
				
			EndIf;
			
			ChildPosition = ChildPosition - 1;
		EndDo;
		
		ChildrenCount = Children.Count();
		If ChildrenCount = 1 AND Children[0].Main Then
			Parents.Delete(Parent);
		Else
			Parent.Count = ChildrenCount - 1;
			Parent.Description = MainChild.Description + " (" + ChildrenCount + ")";
		EndIf;
		
		ParentPosition = ParentPosition - 1;
	EndDo;
	
	Return False;
EndFunction

&AtClient
Procedure AfterConfirmCancelJob(Response, ExecutionParameters) Export
	If Response = DialogReturnCode.Abort Then
		WizardSettings.ShowDialogBeforeClose = False;
		Close();
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal procedures and wizard functions

&AtClientAtServerNoContext
Function WizardButton()
	// Description of wizard button settings.
	//
	// Returns:
	//   Structure - Form button settings.
	//       * Title - Row - button title.
	//       * Tooltip - String - a tooltip for the button.
	//       * Visible - Boolean - if True, the button is visible. The default value is True.
	//       * Availability - Boolean - if True, you can click the button. The default value is True.
	//       * DefaultButton - Boolean - if True, the button is the main button of the form. Default value:
	//                                      False.
	//
	// See also:
	//   "FormButton" in Syntax Assistant.
	//
	Result = New Structure;
	Result.Insert("Title", "");
	Result.Insert("ToolTip", "");
	
	Result.Insert("Enabled", True);
	Result.Insert("Visible", True);
	Result.Insert("DefaultButton", False);
	
	Return Result;
EndFunction

&AtClientAtServerNoContext
Procedure UpdateWizardButtonProperties(WizardButton, Details)
	
	FillPropertyValues(WizardButton, Details);
	WizardButton.ExtendedTooltip.Title = Details.ToolTip;
	
EndProcedure

#EndRegion