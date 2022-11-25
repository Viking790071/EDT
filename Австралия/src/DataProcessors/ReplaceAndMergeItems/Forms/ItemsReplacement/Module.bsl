// This form is parameterized.
//
// Parameters:
//     RefSet - Array, ValueList - a set of items to analyze.
//                                            The parameter can be a collection of objects that have the "Reference" field.
//

////////////////////////////////////////////////////////////////////////////////
// FORM

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("ru = 'Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	// Moving parameters to the ReferencesToReplace table.
	// Initializing the following attributes: ReplacementItem, ReferencesToReplaceCommonOwner, ParameterErrorText.
	InitializeReferencesToReplace(RefArrayFromList(Parameters.RefSet));
	If Not IsBlankString(ParametersErrorText) Then
		Return; // A warning will be issued on opening.
	EndIf;
	
	HasRightToDeletePermanently = AccessRight("DataAdministration", Metadata);
	ReplacementNotificationEvent        = DataProcessors.ReplaceAndMergeItems.ReplacementNotificationEvent();
	CurrentDeletionOption          = "Check";
	
	// Initializing a dynamic list on the form - selection form imitation.
	BasicMetadata = ReplacementItem.Metadata();
	List.CustomQuery = False;
	
	DynamicListParameters = Common.DynamicListPropertiesStructure();
	DynamicListParameters.MainTable = BasicMetadata.FullName();
	DynamicListParameters.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, DynamicListParameters);
	
	Items.Add("ListReferenceNew", Type("FormField"), Items.ListItem).DataPath = "List.Ref";
	
	// A code can be added only if it exists.
	If PossibleReferenceCode(ReplacementItem, New Map) <> Undefined Then
		NewColumn = Items.Add("ListCodeNew", Type("FormField"), Items.List);
		NewColumn.DataPath = "List.Code";
	EndIf;
	
	Items["ListReferenceNew"].Title = NStr("ru = 'Наименование'; en = 'Description'; pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Bezeichnung'");
	
	Items.List.ChangeRowOrder = False;
	Items.List.ChangeRowSet  = False;
	
	ItemsToReplaceList = New ValueList;
	ItemsToReplaceList.LoadValues(RefsToReplace.Unload().UnloadColumn("Ref"));
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Ref",
		ItemsToReplaceList,
		DataCompositionComparisonType.NotInList,
		NStr("ru = 'Не показывать заменяемые'; en = 'Do not show replaceable items'; pl = 'Nie pokazuj wymiennych elementów';es_ES = 'No mostrar los reemplazados';es_CO = 'No mostrar los reemplazados';tr = 'Değiştirileni gösterme';it = 'Non mostrare elementi sostituibili';de = 'Zeige nicht ersetzte'"),
		True,
		DataCompositionSettingsItemViewMode.Inaccessible,
		"5bf5cd06-c1fd-4bd3-94b9-4e9803e90fd5");
	
	If ReferencesToReplaceCommonOwner <> Undefined Then 
		CommonClientServer.SetDynamicListFilterItem(List, "Owner", ReferencesToReplaceCommonOwner );
	EndIf;
	
	If RefsToReplace.Count() > 1 Then
		Items.SelectedItemTypeLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Выберите один из элементов ""%1"", на который следует заменить выбранные значения (%2):'; en = 'Select one of the ""%1"" items the selected values (%2) should be replaced with:'; pl = 'Wybierz jeden z elementów ""%1"", na które wybrane wartości (%2) powinny zostać zastąpione przez:';es_ES = 'Seleccionar uno de los ""%1"" artículos, los valores seleccionados (%2) tienen que reemplazarse por:';es_CO = 'Seleccionar uno de los ""%1"" artículos, los valores seleccionados (%2) tienen que reemplazarse por:';tr = 'Seçilen değerlerin (%1) değiştirilmesi gereken ""%2"" öğelerinden birini seçin:';it = 'Seleziona uno degli elementi ""%1"" a cui desiderate sostituire i valori selezionati (%2):';de = 'Wählen Sie eines der ""%1"" Elemente, die die ausgewählten Werte (%2) ersetzt werden sollen mit:'"),
			BasicMetadata.Presentation(), RefsToReplace.Count());
	Else
		Title = NStr("ru = 'Замена элемента'; en = 'Item replacement'; pl = 'Wymiana elementów';es_ES = 'Reemplazo de artículo';es_CO = 'Reemplazo de artículo';tr = 'Öğe değiştirme';it = 'Sostituzione di elementi';de = 'Artikel ersetzen'");
		Items.SelectedItemTypeLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Выберите один из элементов ""%1"", на который следует заменить ""%2"":'; en = 'Select one of the ""%1"" items ""%2"" should be replaced with:'; pl = 'Wybierz jeden z ""%1"" elementów ""%2"" na który należy zastąpić:';es_ES = 'Seleccionar uno de los ""%1"" artículos ""%2"" tiene que reemplazarse por:';es_CO = 'Seleccionar uno de los ""%1"" artículos ""%2"" tiene que reemplazarse por:';tr = 'Aşağıdaki ile değiştirilmesi gereken ""%1"" öğelerden ""%2"" birini seçin:';it = 'Selezionare uno degli elementi""%1"", che deve essere sostituito con ""%2"":';de = 'Wählen Sie eines der ""%1"" Elemente ""%2"" sollte ersetzt werden mit:'"),
			BasicMetadata.Presentation(), RefsToReplace[0].Ref);
	EndIf;
	Items.ReplacementItemSelectionTooltip.Title = NStr("ru = 'Элемент для замены не выбран.'; en = 'Replacement item is not selected.'; pl = 'Element zamienny nie jest wybrany.';es_ES = 'Artículo de reemplazo no se ha seleccionado.';es_CO = 'Artículo de reemplazo no se ha seleccionado.';tr = 'Yedek öğe seçilmemiş.';it = 'Elemento da sostituire non selezionato.';de = 'Ersatzelement ist nicht ausgewählt.'");
	
	// Initialization of step-by-step wizard steps.
	InitializeStepByStepWizardSettings();
	
	// 1. Main item selection.
	StepSelect = AddWizardStep(Items.ReplacementItemSelectionStep);
	StepSelect.BackButton.Visible = False;
	StepSelect.NextButton.Title = NStr("ru = 'Заменить >'; en = 'Replace >'; pl = 'Zastąp >';es_ES = 'Reemplazar >';es_CO = 'Reemplazar >';tr = 'Değiştir >';it = 'Sostituire >';de = 'Ersetzen >'");
	StepSelect.NextButton.ToolTip = NStr("ru = 'Начать замену элементов'; en = 'Start replacing items'; pl = 'Zacznij zastępowanie elementów';es_ES = 'Iniciar a reemplazar los artículos';es_CO = 'Iniciar a reemplazar los artículos';tr = 'Öğeleri değiştirmeye başla';it = 'Iniziare la sostituzione elementi';de = 'Ersetzen von Elementen beginnen'");
	StepSelect.CancelButton.Title = NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'");
	StepSelect.CancelButton.ToolTip = NStr("ru = 'Отказаться от замены элементов'; en = 'Cancel item replacement'; pl = 'Odmów zastępowania elementów';es_ES = 'Rechazar el reemplazo de los artículos';es_CO = 'Rechazar el reemplazo de los artículos';tr = 'Öğeleri değiştirmeyi reddet';it = 'Annullare la sostituzione degli elementi';de = 'Ablehnen Elemente zu ersetzen'");
	
	// 2. Waiting for process.
	Step = AddWizardStep(Items.ReplacementStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Прервать замену элементов'; en = 'Abort item replacement'; pl = 'Zatrzymaj zastępowanie elementów';es_ES = 'Parar el reemplazo de artículos';es_CO = 'Parar el reemplazo de artículos';tr = 'Öğe değiştirmeyi durdur';it = 'Interrompere la sostituzione degli elementi';de = 'Stoppen Sie den Elementaustausch'");
	
	// 3. Reference replacement issues.
	Step = AddWizardStep(Items.RetryReplacementStep);
	Step.BackButton.Title = NStr("ru = '< Назад'; en = '< Back'; pl = '< Powrót';es_ES = '< Atrás';es_CO = '< Atrás';tr = '< Geri';it = '< Indietro ';de = '<Zurück'");
	Step.BackButton.ToolTip = NStr("ru = 'Вернуться к выбору целевого элемента'; en = 'Return to master item selection'; pl = 'Wróć do wyboru elementu docelowego';es_ES = 'Volver a la selección de unidades maestras';es_CO = 'Volver a la selección de unidades maestras';tr = 'Ana öğe seçimine geri dön';it = 'Ritorna alla selezione master dell''elemento';de = 'Zurück zur Auswahl der Stammartikel'");
	Step.NextButton.Title = NStr("ru = 'Повторить замену >'; en = 'Retry replacement >'; pl = 'Powtórz wymianę >';es_ES = 'Repetir el reemplazo >';es_CO = 'Repetir el reemplazo >';tr = 'Değiştirmeyi tekrarla >';it = 'Riprovare la sostituzione >';de = 'Ersetzen wiederholen >'");
	Step.NextButton.ToolTip = NStr("ru = 'Повторить замену элементов'; en = 'Retry item replacement'; pl = 'Powtórz wymianę elementów';es_ES = 'Repetir el reemplazo de artículos';es_CO = 'Repetir el reemplazo de artículos';tr = 'Öğe değiştirmeyi tekrarla';it = 'Riprovare la sostituzione degli elementi';de = 'Element ersetzen wiederholen'");
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Закрыть результаты замены элементов'; en = 'Close item replacement results'; pl = 'Zamknij wyniki zastępowania elementów';es_ES = 'Cerrar los resultados del reemplazo de artículos';es_CO = 'Cerrar los resultados del reemplazo de artículos';tr = 'Öğe değiştirmenin sonuçlarını kapatın';it = 'Chiudere i risultati della sostituzione degli elementi';de = 'Schließen Sie die Ergebnisse der Element Ersetzung'");
	
	// 4. Runtime errors.
	Step = AddWizardStep(Items.ErrorOccurredStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	
	// Updating form items.
	WizardSettings.CurrentStep = StepSelect;
	VisibleEnabled(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Checking whether an error message is required.
	If Not IsBlankString(ParametersErrorText) Then
		Cancel = True;
		ShowMessageBox(, ParametersErrorText);
		Return;
	EndIf;
	
	// Running wizard.
	OnActivateWizardStep();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Items.WizardSteps.CurrentPage <> Items.ReplacementStep
		Or Not WizardSettings.ShowDialogBeforeClose Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	QuestionText = NStr("ru = 'Прервать замену элементов и закрыть форму?'; en = 'Stop replacing items and close the form?'; pl = 'Przerwać wymianę elementów i zamknąć formularz?';es_ES = '¿Parar el reemplazo de artículos y cerrar el formulario?';es_CO = '¿Parar el reemplazo de artículos y cerrar el formulario?';tr = 'Öğeleri değiştirmeyi bırak ve formu kapat?';it = 'Fermare la sostituzione degli elementi e chiudere il modulo?';de = 'Stoppen Sie den Austausch von Elementen und schließen Sie das Formular?'");
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Abort, NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'"));
	Buttons.Add(DialogReturnCode.No,      NStr("ru = 'Не прерывать'; en = 'Do not stop'; pl = 'Nie przerywać';es_ES = 'No interrumpir';es_CO = 'No interrumpir';tr = 'Kesme';it = 'Non fermare';de = 'Nicht unterbrechen'"));
	
	Handler = New NotifyDescription("AfterConfirmCancelJob", ThisObject);
	ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.No);
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// ITEMS

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReplacementItemSelectionTooltipURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	If FormattedStringURL = "SwitchDeletionMode" Then
		If CurrentDeletionOption = "Directly" Then
			CurrentDeletionOption = "Check" 
		Else
			CurrentDeletionOption = "Directly" 
		EndIf;
		
		GenerateReplacementItemAndTooltip(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure DetailsRefClick(Item)
	StandardSubsystemsClient.ShowDetailedInfo(Undefined, Item.ToolTip);
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE List

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("GenerateReplacementItemAndTooltipDeferred", 0.01, True);
	
EndProcedure

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	StepReplacementItemSelectionOnClickNextButton();
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE UnsuccessfulReplacements

#Region UnsuccessfulReplacementsFormTableItemEventHandlers

&AtClient
Procedure UnsuccessfulReplacementsOnActivateRow(Item)
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		FailureReasonDetails = "";
	Else
		FailureReasonDetails = CurrentData.DetailedReason;
	EndIf;
EndProcedure

&AtClient
Procedure UnsuccessfulReplacementsChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	Ref = UnsuccessfulReplacements.FindByID(RowSelected).Ref;
	If Ref <> Undefined Then
		ShowValue(, Ref);
	EndIf;

EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// COMMANDS

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
Procedure OpenUnsuccessfulReplacementItem(Command)
	CurrentData = Items.UnsuccessfulReplacements.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllUnsuccessfulReplacements(Command)
	FormTree = Items.UnsuccessfulReplacements;
	For Each Item In UnsuccessfulReplacements.GetItems() Do
		FormTree.Expand(Item.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure CollapseAllUnsuccessfulReplacements(Command)
	FormTree = Items.UnsuccessfulReplacements;
	For Each Item In UnsuccessfulReplacements.GetItems() Do
		FormTree.Collapse(Item.GetID());
	EndDo;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

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
	
	If CurrentPage = Items.ReplacementItemSelectionStep Then
		
		GenerateReplacementItemAndTooltip(ThisObject);
		
	ElsIf CurrentPage = Items.ReplacementStep Then
		
		WizardSettings.ShowDialogBeforeClose = True;
		ReplacementItemResult = ReplacementItem; // Saving start parameters.
		RunBackgroundJobClient();
		
	ElsIf CurrentPage = Items.RetryReplacementStep Then
		
		// Updating number of failures.
		Unsuccessful = New Map;
		For Each Row In UnsuccessfulReplacements.GetItems() Do
			Unsuccessful.Insert(Row.Ref, True);
		EndDo;
		
		ReplacementsCount = RefsToReplace.Count();
		Items.UnsuccessfulReplacementsResult.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось заменить элементы (%1 из %2). В некоторых местах использования не может быть произведена
			           |автоматическая замена на ""%3""'; 
			           |en = 'Cannot replace items (%1 of %2). Cannot
			           |automatically replace with ""%3"" in some usage instances'; 
			           |pl = 'Nie można wymienić elementów (%1 z %2). W niektórych miejscach użytkowania 
			           |nie można wykonać %3 automatycznej wymiany.';
			           |es_ES = 'No se puede reemplazar los artículos (%1 de %2). EN algunos sitios de uso, un reemplazo
			           |automático para %3 no puede ejecutarse.';
			           |es_CO = 'No se puede reemplazar los artículos (%1 de %2). EN algunos sitios de uso, un reemplazo
			           |automático para %3 no puede ejecutarse.';
			           |tr = 'Öğeler değiştirilemiyor (%1''in %2). Bazı kullanım yerlerinde, 
			           |otomatik bir değiştirme işlemi yapılamaz%3.';
			           |it = 'Impossibile sostituire gli elementi (%1 di %2). Impossibile
			           |sostituire automaticamente con ""%3"" in qualche contesto d''uso';
			           |de = 'Es ist nicht möglich, Elemente zu ersetzen (%1 von %2). AN einigen Einsatzorten kann ein automatischer
			           |Ersatz für %3 nicht ausgeführt werden.'"),
			Unsuccessful.Count(),
			ReplacementsCount,
			ReplacementItem);
		
		// Generating a list of successful replacements and clearing a list of items to replace.
		UpdatedItemsList = New Array;
		UpdatedItemsList.Add(ReplacementItem);
		For Number = 1 To ReplacementsCount Do
			ReverseIndex = ReplacementsCount - Number;
			Ref = RefsToReplace[ReverseIndex].Ref;
			If Ref <> ReplacementItem AND Unsuccessful[Ref] = Undefined Then
				RefsToReplace.Delete(ReverseIndex);
				UpdatedItemsList.Add(Ref);
			EndIf;
		EndDo;
		
		// Notification of completed replacements.
		NotifyOfSuccessfulReplacement(UpdatedItemsList);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepNext()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.ReplacementItemSelectionStep Then
		
		StepReplacementItemSelectionOnClickNextButton();
		
	ElsIf CurrentPage = Items.RetryReplacementStep Then
		
		GoToWizardStep(Items.ReplacementStep);
		
	Else
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepBack()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.RetryReplacementStep Then
		
		GoToWizardStep(Items.ReplacementItemSelectionStep);
		
	Else
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf - 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepCancel()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.ReplacementStep Then
		
		WizardSettings.ShowDialogBeforeClose = False;
		
	EndIf;
	
	If IsOpen() Then
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal replace and merge items procedures

&AtClient
Procedure StepReplacementItemSelectionOnClickNextButton()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	ElsIf RefsToReplace.Count() = 1 AND CurrentData.Ref = RefsToReplace.Get(0).Ref Then
		ShowMessageBox(, NStr("ru = 'Нельзя заменять элемент сам на себя.'; en = 'Cannot replace an item with itself.'; pl = 'Element nie może być zastąpiony sam sobą.';es_ES = 'Un artículo no puede reemplazarse por él mismo.';es_CO = 'Un artículo no puede reemplazarse por él mismo.';tr = 'Bir öğe kendi ile değiştirilemez.';it = 'Impossibile sostituire l''elemento su se stesso.';de = 'Ein Element kann nicht durch sich selbst ersetzt werden.'"));
		Return;
	ElsIf AttributeValue(CurrentData, "IsFolder", False) Then
		ShowMessageBox(, NStr("ru = 'Нельзя заменять элемент на группу.'; en = 'Cannot replace an item with a group.'; pl = 'Nie można zastąpić elementu grupą.';es_ES = 'No se puede reemplazar el artículo por un grupo.';es_CO = 'No se puede reemplazar el artículo por un grupo.';tr = 'Öğe grupla değiştirilemiyor.';it = 'Impossibile sostituire l''elemento per gruppo.';de = 'Element kann nicht durch Gruppe ersetzt werden.'"));
		Return;
	EndIf;
	
	CurrentOwner = AttributeValue(CurrentData, "Owner");
	If CurrentOwner <> ReferencesToReplaceCommonOwner Then
		Text = NStr("ru = 'Нельзя заменять на элемент, подчиненный другому владельцу.
			|У выбранного элемента владелец ""%1"", а у заменяемого - ""%2"".'; 
			|en = 'Cannot replace an item with the item that belongs to another owner.
			|The owner of the selected item is ""%1"", the item you want to replace belongs to ""%2"".'; 
			|pl = 'Nie można element zastąpić obiektem podrzędnym, który jest podporządkowany do innego użytkownika.
			|Wybrany element%1ma właściciela, a zastąpiony element%2ma właściciela.';
			|es_ES = 'Usted no puede reemplazarlo por el objeto subordinado a otro usuario.
			|El artículo seleccionado tiene %1 como un propietario, y el artículo reemplazado tiene %2 como un propietario.';
			|es_CO = 'Usted no puede reemplazarlo por el objeto subordinado a otro usuario.
			|El artículo seleccionado tiene %1 como un propietario, y el artículo reemplazado tiene %2 como un propietario.';
			|tr = 'Onu başka bir kullanıcıya bağlı nesneyle değiştiremezsiniz. 
			|Seçilen öğenin %1 sahip olarak ve değiştirilen öğenin %2 sahip olarak vardır.';
			|it = 'Impossibile sostituire un elemento con l''elemento che appartiene a un altro proprietario.
			|Il proprietario dell''elemento selezionato è ""%1"", mentre l''elemento che si vuole sostituire appartiene a ""%2"".';
			|de = 'Sie können es nicht durch das Objekt ersetzen, das einem anderen Benutzer untergeordnet ist.
			|Das ausgewählte Element hat %1 einen Eigentümer und das ersetzte Element hat %2 einen Eigentümer.'");
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(Text, CurrentOwner, ReferencesToReplaceCommonOwner));
		Return;
	EndIf;
	
	If AttributeValue(CurrentData, "DeletionMark", False) Then
		// Attempt to replace with an item marked for deletion.
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Элемент %1 помечен на удаление. Продолжить?'; en = 'Item %1 is marked for deletion. Continue?'; pl = 'Element %1 jest oznaczony do usunięcia. Kontynuować?';es_ES = 'El artículo %1 está marcado para borrar. ¿Continuar?';es_CO = 'El artículo %1 está marcado para borrar. ¿Continuar?';tr = 'Öğe %1 silinmek üzere işaretlenmiştir. Devam et?';it = 'Elemento %1 è contrassegnato per l''eliminazione. Continuare?';de = 'Das Element %1 ist zum Löschen markiert. Fortsetzen?'"),
			CurrentData.Ref);
		Details = New NotifyDescription("ConfirmItemSelection", ThisObject);
		ShowQueryBox(Details, Text, QuestionDialogMode.YesNo);
	Else
		// Additional check for applied data is required.
		AppliedAreaReplacementAvailabilityCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyOfSuccessfulReplacement(Val DataList)
	// Changes of items where replacements are performed.
	TypesList = New Map;
	For Each Item In DataList Do
		Type = TypeOf(Item);
		If TypesList[Type] = Undefined Then
			NotifyChanged(Type);
			TypesList.Insert(Type, True);
		EndIf;
	EndDo;
	
	// Common notification
	If TypesList.Count()>0 Then
		Notify(ReplacementNotificationEvent, , ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure GenerateReplacementItemAndTooltipDeferred()
	GenerateReplacementItemAndTooltip(ThisObject);
EndProcedure

&AtClient
Procedure ConfirmItemSelection(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	// Additional check by applied data.
	AppliedAreaReplacementAvailabilityCheck();
EndProcedure

&AtClient
Procedure AppliedAreaReplacementAvailabilityCheck()
	// Checking items replacement for validity in terms of applied data.
	ErrorText = CheckCanReplaceReferences();
	If Not IsBlankString(ErrorText) Then
		DialogSettings = New Structure;
		DialogSettings.Insert("SuggestDontAskAgain", False);
		DialogSettings.Insert("Picture", PictureLib.Warning32);
		DialogSettings.Insert("DefaultButton", 0);
		DialogSettings.Insert("Title", NStr("ru = 'Невозможно заменить элементы'; en = 'Cannot replace items'; pl = 'Brak możliwości zastąpienia elementów';es_ES = 'Usted no puede reemplazar los artículos';es_CO = 'Usted no puede reemplazar los artículos';tr = 'Öğeleri değiştiremezsiniz';it = 'Impossibile sostituire gli elementi';de = 'Sie können keine Elemente ersetzen'"));
		
		Buttons = New ValueList;
		Buttons.Add(0, NStr("ru = 'ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
		
		StandardSubsystemsClient.ShowQuestionToUser(Undefined, ErrorText, Buttons, DialogSettings);
		Return;
	EndIf;
	
	GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateReplacementItemAndTooltip(Context)
	
	CurrentData = Context.Items.List.CurrentData;
	// Skipping empty data and groups
	If CurrentData = Undefined Or AttributeValue(CurrentData, "IsFolder", False) Then
		Return;
	EndIf;
	Context.ReplacementItem = CurrentData.Ref;
	
	Count = Context.RefsToReplace.Count();
	If Count = 1 Then
		
		If Context.HasRightToDeletePermanently Then
			If Context.CurrentDeletionOption = "Check" Then
				TooltipText = NStr("ru = 'Выбранный элемент будет заменен на ""%1""
					|и <a href = ""SwitchDeletionMode"">помечен на удаление</a>.'; 
					|en = 'The selected item will be replaced with ""%1""
					|and <a href = ""SwitchDeletionMode"">marked for deletion</a>.'; 
					|pl = 'Wybrany element zostanie zostanie zastąpiony ""%1""
					|i <a href = ""SwitchDeletionMode"">i oznaczony do usunięcia</a>.';
					|es_ES = 'El artículo seleccionado se
					|reemplazará por %1 y <a href = ""SwitchDeletionMode"">se marcará para borrar</a>.';
					|es_CO = 'El artículo seleccionado se
					|reemplazará por %1 y <a href = ""SwitchDeletionMode"">se marcará para borrar</a>.';
					|tr = 'Seçilen öğe ""%1"" ile değiştirilecek
					|ve <a href = ""SwitchDeletionMode"">silinmek üzere işaretlenecek</a>.';
					|it = 'Elemento selezionato sarà sostituito al""%1
					| e <a href = ""SwitchDeletionMode"">contrassegnato per l''eliminazione </a>.';
					|de = 'Das ausgewählte Element wird
					|ersetzt durch %1 und <a href = ""SwitchDeletionMode"">zum Löschen markiert</a>.'");
			Else
				TooltipText = NStr("ru = 'Выбранный элемент будет заменен на ""%1""
					|и <a href = ""SwitchDeletionMode"">удален безвозвратно</a>.'; 
					|en = 'The selected item will be replaced with ""%1""
					|and <a href = ""SwitchDeletionMode"">permanently deleted</a>.'; 
					|pl = 'Wybrany element zostanie zastąpiony ""%1""
					|i <a href = ""SwitchDeletionMode"">trwale usunięty</a>.';
					|es_ES = 'El artículo seleccionado se
					|reemplazará por %1 y <a href = ""SwitchDeletionMode"">se borrará para siempre</a>.';
					|es_CO = 'El artículo seleccionado se
					|reemplazará por %1 y <a href = ""SwitchDeletionMode"">se borrará para siempre</a>.';
					|tr = 'Seçilen öğe ""%1"" ile değiştirilecek
					|ve <a href = ""SwitchDeletionMode"">kalıcı olarak silinecek</a>.';
					|it = 'Elemento selezionato sarà sostituito al ""%1""
					|e <a href = ""SwitchDeletionMode"">eliminato definitivamente</a>.';
					|de = 'Das ausgewählte Element wird
					|ersetzt durch %1 und <a href = ""SwitchDeletionMode"">dauerhaft gelöscht</a>.'");
			EndIf;
		Else
			TooltipText = NStr("ru = 'Выбранный элемент будет заменен на ""%1""
				|и помечен на удаление.'; 
				|en = 'The selected item will be replaced with ""%1""
				| and marked for deletion.'; 
				|pl = 'Wybrany element zostanie wymieniony na ""%1""
				|i zaznaczony do usunięcia.';
				|es_ES = 'El artículo seleccionado se reemplazará por ""%1""
				|y se marcará para borrar.';
				|es_CO = 'El artículo seleccionado se reemplazará por ""%1""
				|y se marcará para borrar.';
				|tr = 'Seçilen öğe ""%1"" ile değiştirilecek
				|ve silinmek üzere işaretlenecek.';
				|it = 'Elemento selezionato sarà sostituito al""%1
				| e contrassegnato per l''eliminazione.';
				|de = 'Das ausgewählte Element wird durch ""%1""
				|ersetzt und zum Löschen markiert.'");
		EndIf;
		
		TooltipText = StringFunctionsClientServer.SubstituteParametersToString(TooltipText, Context.ReplacementItem);
		Context.Items.ReplacementItemSelectionTooltip.Title = StringFunctionsClientServer.FormattedString(TooltipText);
		
	Else
		
		If Context.HasRightToDeletePermanently Then
			If Context.CurrentDeletionOption = "Check" Then
				TooltipText = NStr("ru = 'Выбранные элементы (%1) будут заменены на ""%2""
					|и <a href = ""SwitchDeletionMode"">помечены на удаление</a>.'; 
					|en = 'The selected items (%1) will be replaced with ""%2""
					|and <a href = ""SwitchDeletionMode"">marked for deletion</a>.'; 
					|pl = 'Wybrane elementy (%1) zostaną zastąpione ""%2""
					|i <a href = ""SwitchDeletionMode"">oznaczone do usunięcia</a>.';
					|es_ES = 'Los artículos seleccionados (%1) se
					|reemplazarán por %2 y <a href = ""SwitchDeletionMode"">se marcarán para borrar</a>.';
					|es_CO = 'Los artículos seleccionados (%1) se
					|reemplazarán por %2 y <a href = ""SwitchDeletionMode"">se marcarán para borrar</a>.';
					|tr = 'Seçilen öğeler (%1), ""%2"" ile değiştirilecek
					|ve <a href = ""SwitchDeletionMode"">silinmek üzere işaretlenecek</a>.';
					|it = 'Gli elementi selezionati (%1) saranno sostituiti con ""%2 ""
					| e <a href = ""SwitchDeletionMode""> contrassegnati per l''eliminazione</a>.';
					|de = 'Die ausgewählten Elemente (%1) werden
					|ersetzt durch %2 und <a href = ""SwitchDeletionMode"">zum Löschen markiert</a>.'");
			Else
				TooltipText = NStr("ru = 'Выбранные элементы (%1) будут заменены на ""%2""
					|и <a href = ""SwitchDeletionMode"">удалены безвозвратно</a>.'; 
					|en = 'The selected items (%1) will be replaced with ""%2""
					|and <a href = ""SwitchDeletionMode"">permanently deleted</a>.'; 
					|pl = 'Wybrane elementy (%1) zostaną zastąpione ""%2""
					|i <a href = ""SwitchDeletionMode"">trwale usunięte</a>.';
					|es_ES = 'Los artículos seleccionado (%1) se
					|reemplazarán por %2 y <a href = ""SwitchDeletionMode"">se borrarán para siempre</a>.';
					|es_CO = 'Los artículos seleccionado (%1) se
					|reemplazarán por %2 y <a href = ""SwitchDeletionMode"">se borrarán para siempre</a>.';
					|tr = 'Seçilen öğeler (%1), ""%2"" ile değiştirilecek
					|ve <a href = ""SwitchDeletionMode"">kalıcı olarak silinecek</a>.';
					|it = 'Gli elementi selezionati (%1) saranno sostituiti con ""%2""
					|e <a href = ""SwitchDeletionMode"">cancellati in modo permanenete</a>.';
					|de = 'Die ausgewählten Elemente (%1) werden
					|ersetzt durch %2 und <a href = ""SwitchDeletionMode"">auerhaft gelöscht</a>.'");
			EndIf;
		Else
			TooltipText = NStr("ru = 'Выбранные элементы (%1) будут заменены на ""%2""
				|и помечен на удаление.'; 
				|en = 'The selected items (%1) will be replaced with ""%2""
				|and marked for deletion.'; 
				|pl = 'Wybrane elementy (%1) zostaną wymienione na ""%2""
				|i zaznaczone do usunięcia.';
				|es_ES = 'Los artículos seleccionados (%1) se reemplazarán por ""%2""
				| y se marcarán para borrar.';
				|es_CO = 'Los artículos seleccionados (%1) se reemplazarán por ""%2""
				| y se marcarán para borrar.';
				|tr = 'Seçilen öğeler (%1), ""%2"" ile değiştirilecek
				|ve silinmek üzere işaretlenecek.';
				|it = 'Gli elementi selezionati (%1) saranno sostituiti con ""%2""
				|e contrassegnati per l''eliminazione.';
				|de = 'Die ausgewählten Elemente (%1) werden durch ""%2""
				|ersetzt und zum Löschen markiert.'");
		EndIf;
			
		TooltipText = StringFunctionsClientServer.SubstituteParametersToString(TooltipText, Count, Context.ReplacementItem);
		Context.Items.ReplacementItemSelectionTooltip.Title = StringFunctionsClientServer.FormattedString(TooltipText);
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function AttributeValue(Val Data, Val AttributeName, Val ValueIfNotFound = Undefined)
	// Gets an attribute value safely.
	Trial = New Structure(AttributeName);
	
	FillPropertyValues(Trial, Data);
	If Trial[AttributeName] <> Undefined Then
		// There is a value
		Return Trial[AttributeName];
	EndIf;
	
	// Value in data might be set to Undefined.
	Trial[AttributeName] = True;
	FillPropertyValues(Trial, Data);
	If Trial[AttributeName] <> True Then
		Return Trial[AttributeName];
	EndIf;
	
	Return ValueIfNotFound;
EndFunction

&AtServer
Function CheckCanReplaceReferences()
	
	ReplacementPairs = New Map;
	For Each Row In RefsToReplace Do
		ReplacementPairs.Insert(Row.Ref, ReplacementItem);
	EndDo;
	
	ReplacementParameters = New Structure("DeletionMethod", CurrentDeletionOption);
	Return DuplicateObjectDetection.CheckCanReplaceItemsString(ReplacementPairs, ReplacementParameters);
	
EndFunction

&AtServerNoContext
Function RefArrayFromList(Val References)
	// Converts an array, list of values, or collection to an array.
	
	ParameterType = TypeOf(References);
	If References = Undefined Then
		RefsArray = New Array;
		
	ElsIf ParameterType  = Type("ValueList") Then
		RefsArray = References.UnloadValues();
		
	ElsIf ParameterType = Type("Array") Then
		RefsArray = References;
		
	Else
		RefsArray = New Array;
		For Each Item In References Do
			RefsArray.Add(Item.Ref);
		EndDo;
		
	EndIf;
	
	Return RefsArray;
EndFunction

&AtServerNoContext
Function PossibleReferenceCode(Val Ref, MetadataCache)
	// Returns:
	//     Arbitrary - catalog code and so on if metadata has a code,
	//     Undefined if there is no code.
	Meta = Ref.Metadata();
	HasCode = MetadataCache[Meta];
	
	If HasCode = Undefined Then
		// Checking whether the code exists.
		Test = New Structure("CodeLength", 0);
		FillPropertyValues(Test, Meta);
		HasCode = Test.CodeLength > 0;
		
		MetadataCache[Meta] = HasCode;
	EndIf;
	
	Return ?(HasCode, Ref.Code, Undefined);
EndFunction

&AtServer
Procedure InitializeReferencesToReplace(Val RefsArray)
	
	RefsCount = RefsArray.Count();
	If RefsCount = 0 Then
		ParametersErrorText = NStr("ru = 'Не указано ни одного элемента для замены.'; en = 'No items are selected to be replaced.'; pl = 'Nie określono elementu do wymiany.';es_ES = 'Ningún artículo para el reemplazo se ha especificado.';es_CO = 'Ningún artículo para el reemplazo se ha especificado.';tr = 'Değiştirme için hiçbir öğe belirtilmemiş.';it = 'Nessun elemento selezionato per la sostituzione.';de = 'Kein Artikel zum Ersetzen angegeben.'");
		Return;
	EndIf;
	
	ReplacementItem = RefsArray[0];
	
	BasicMetadata = ReplacementItem.Metadata();
	Characteristics = New Structure("Owners, Hierarchical, HierarchyType", New Array, False);
	FillPropertyValues(Characteristics, BasicMetadata);
	
	HasOwners = Characteristics.Owners.Count() > 0;
	HasGroups    = Characteristics.Hierarchical AND Characteristics.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems;
	
	AdditionalFields = "";
	If HasOwners Then
		AdditionalFields = AdditionalFields + ", Owner AS Owner";
	Else
		AdditionalFields = AdditionalFields + ", UNDEFINED AS Owner";
	EndIf;
	
	If HasGroups Then
		AdditionalFields = AdditionalFields + ", IsFolder AS IsFolder";
	Else
		AdditionalFields = AdditionalFields + ", FALSE AS IsFolder";
	EndIf;
	
	TableName = BasicMetadata.FullName();
	Query = New Query(
		"SELECT
		|Ref AS Ref
		|" + AdditionalFields + "
		|INTO RefsToReplace
		|FROM
		|	" + TableName + "
		|WHERE
		|	Ref IN (&RefSet)
		|INDEX BY
		|	Owner,
		|	IsFolder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	COUNT(DISTINCT Owner) AS OwnersCount,
		|	MIN(Owner)              AS CommonOwner,
		|	MAX(IsFolder)            AS HasGroups,
		|	COUNT(Ref)             AS RefsCount
		|FROM
		|	RefsToReplace
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	DestinationTable.Ref
		|FROM
		|	" + TableName + " AS DestinationTable
		|		LEFT JOIN RefsToReplace AS RefsToReplace
		|		ON DestinationTable.Ref = RefsToReplace.Ref
		|		AND DestinationTable.Owner = RefsToReplace.Owner
		|WHERE
		|	RefsToReplace.Ref IS NULL
		|	AND NOT DestinationTable.IsFolder");
		
	If Not HasOwners Then
		Query.Text = StrReplace(Query.Text, "AND DestinationTable.Owner = RefsToReplace.Owner", "");
	EndIf;
	If Not HasGroups Then
		Query.Text = StrReplace(Query.Text, "AND NOT DestinationTable.IsFolder", "");
	EndIf;
	Query.SetParameter("RefSet", RefsArray);
	
	Result = Query.ExecuteBatch();
	Conditions = Result[1].Unload()[0];
	If Conditions.HasGroups Then
		ParametersErrorText = NStr("ru = 'Один из заменяемых элементов является группой.
		                                   |Группы не могут быть заменены.'; 
		                                   |en = 'One of the replaced items is a group.
		                                   |Groups cannot be replaced.'; 
		                                   |pl = 'Jednym z wymienionych elementów jest grupa.
		                                   |Grupy nie mogą być zastąpione.';
		                                   |es_ES = 'Uno de los artículos reemplazados es un grupo.
		                                   |Grupos no pueden reemplazarse.';
		                                   |es_CO = 'Uno de los artículos reemplazados es un grupo.
		                                   |Grupos no pueden reemplazarse.';
		                                   |tr = 'Birleştirilmiş öğelerden biri bir gruptur. 
		                                   |Gruplar birleştirilemez.';
		                                   |it = 'Uno degli elementi sostituiti è un gruppo.
		                                   |I gruppi non possono essere sostituiti.';
		                                   |de = 'Eines der ersetzten Elemente ist eine Gruppe.
		                                   |Gruppen können nicht ersetzt werden.'");
		Return;
	ElsIf Conditions.OwnersCount > 1 Then 
		ParametersErrorText = NStr("ru = 'У заменяемых элементов разные владельцы.
		                                   |Такие элементы не могут быть заменены.'; 
		                                   |en = 'Replaceable items have different owners. 
		                                   |Such items cannot be replaced.'; 
		                                   |pl = 'Wymienione elementy mają różnych właścicieli.
		                                   |Takie przedmioty nie mogą być zastąpione.';
		                                   |es_ES = 'Artículos reemplazado tienen diferentes propietarios.
		                                   |Estos artículos no pueden reemplazarse.';
		                                   |es_CO = 'Artículos reemplazado tienen diferentes propietarios.
		                                   |Estos artículos no pueden reemplazarse.';
		                                   |tr = 'Değiştirilmiş öğelerin farklı sahipleri var. 
		                                   |Bu tür maddeler birleştirilemez.';
		                                   |it = 'Gli elementi da sostituire hanno proprietari deversi. 
		                                   |Tali elementi non possono essere sostituiti.';
		                                   |de = 'Ersetzte Gegenstände haben unterschiedliche Besitzer.
		                                   |Solche Elemente können nicht ersetzt werden.'");
		Return;
	ElsIf Conditions.RefsCount <> RefsCount Then
		ParametersErrorText = NStr("ru = 'Все заменяемые элементы должны быть одного типа.'; en = 'All replaceable items must be of the same type.'; pl = 'Wszystkie wymienne elementy muszą być tego samego typu.';es_ES = 'Todos los artículos reemplazables tienen que ser del mismo tipo.';es_CO = 'Todos los artículos reemplazables tienen que ser del mismo tipo.';tr = 'Tüm değiştirilebilir öğeler aynı tipte olmalıdır.';it = 'Tutti gli elementi sostituibili devono essere dello stesso tipo.';de = 'Alle austauschbaren Elemente müssen vom gleichen Typ sein.'");
		Return;
	EndIf;
	
	If Result[2].Unload().Count() = 0 Then
		If RefsCount > 1 Then
			ParametersErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Выбранные элементы (%1) не на что заменить.'; en = 'There is nothing to replace the selected items (%1) with.'; pl = 'Wybranych elementów (%1) nie ma czym zastąpić.';es_ES = 'No hay nada para reemplazar los artículos seleccionados (%1) por.';es_CO = 'No hay nada para reemplazar los artículos seleccionados (%1) por.';tr = 'Seçilen öğeleri (%1) ile değiştirmek için hiçbir şey yoktur.';it = 'Non c''è niente per  sostituire l''elemento selezionato (%1).';de = 'Es gibt nichts, um die ausgewählten Elemente (%1) zu ersetzen.'"), RefsCount);
		Else
			ParametersErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Выбранный элемент ""%1"" не на что заменить.'; en = 'There is nothing to replace selected item ""%1"" with.'; pl = 'Wybrany element ""%1"" nie ma czym zastąpić.';es_ES = 'No hay nada para reemplazar el artículo seleccionado ""%1"" por.';es_CO = 'No hay nada para reemplazar el artículo seleccionado ""%1"" por.';tr = '""%1"" ile seçilen öğeyi değiştirecek hiçbir şey yok.';it = 'Non c''è niente per  sostituire l''elemento selezionato ""%1"".';de = 'Es gibt nichts, um das ausgewählte Element ""%1"" zu ersetzen.'"), Common.SubjectString(ReplacementItem));
		EndIf;
		Return;
	EndIf;
	
	ReferencesToReplaceCommonOwner = ?(HasOwners, Conditions.CommonOwner, Undefined);
	For Each Item In RefsArray Do
		RefsToReplace.Add().Ref = Item;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Time-consuming operations

&AtClient
Procedure RunBackgroundJobClient()
	// Preparing method parameters.
	MethodParameters = New Structure("ReplacementPairs, Parameters");
	MethodParameters.ReplacementPairs = New Map;
	For Each Row In RefsToReplace Do
		MethodParameters.ReplacementPairs.Insert(Row.Ref, ReplacementItem);
	EndDo;
	MethodParameters.Parameters = New Structure;
	MethodParameters.Parameters.Insert("DeletionMethod", CurrentDeletionOption);
	MethodParameters.Parameters.Insert("IncludeBusinessLogic", True);
	MethodParameters.Parameters.Insert("ReplacePairsInTransaction", False);
	
	// Run the background job for replacement.
	Job = RunBackgroundJob(MethodParameters, UUID);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("AfterCompleteBackgroundJob", ThisObject);
	
	TimeConsumingOperationsClient.WaitForCompletion(Job, Handler, WaitSettings);
EndProcedure

&AtServerNoContext
Function RunBackgroundJob(Val MethodParameters, Val UUID)
	MethodName = "DuplicateObjectDetection.ReplaceReferences";
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("ru = 'Поиск и удаление дублей: Замена ссылок'; en = 'Duplicates search and deletion: Reference replacement'; pl = 'Wyszukaj i usuń duplikaty: Wymiana linków';es_ES = 'Buscar y borrar los duplicados: Reemplazo de referencias';es_CO = 'Buscar y borrar los duplicados: Reemplazo de referencias';tr = 'Çiftleri ara ve sil: Referans değişimi';it = 'Ricerca e cancellazione di duplicati: Sostituzione di collegamento';de = 'Suchen und Löschen von Duplikaten: Ersetzen von Referenzen'");
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings);
EndFunction

&AtClient
Procedure AfterCompleteBackgroundJob(Job, AdditionalParameters) Export
	WizardSettings.ShowDialogBeforeClose = False;
	
	If Job.Status <> "Completed" Then
		// Background job is completed with error.
		BriefDescription = NStr("ru = 'При замене элементов возникла ошибка:'; en = 'An error occurred while replacing items:'; pl = 'Podczas wymiany elementów wystąpił błąd:';es_ES = 'Ha ocurrido un error al reemplazar los elementos:';es_CO = 'Ha ocurrido un error al reemplazar los elementos:';tr = 'Nesne alışverişinde hata oluştu:';it = 'Un errore si è registrato durante la sostituzione elementi:';de = 'Beim Ersetzen von Elementen ist ein Fehler aufgetreten:'") + Chars.LF + Job.BriefErrorPresentation;
		More = BriefDescription + Chars.LF + Chars.LF + Job.DetailedErrorPresentation;
		Items.ErrorTextLabel.Title = BriefDescription;
		Items.DetailsRef.ToolTip    = More;
		GoToWizardStep(Items.ErrorOccurredStep);
		Activate();
		Return;
	EndIf;
	
	HasUnsuccessfulReplacements = FillUnsuccessfulReplacements(Job.ResultAddress);
	If HasUnsuccessfulReplacements Then
		// Partially successful - display details.
		GoToWizardStep(Items.RetryReplacementStep);
		Activate();
	Else
		// Completely successful - display notification and close the form.
		Count = RefsToReplace.Count();
		If Count = 1 Then
			ResultingText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Элемент ""%1"" заменен на ""%2""'; en = 'The %1 item was replaced with %2'; pl = 'Element (%1) zostanie zastąpiony przez ""%2""';es_ES = 'El artículo ""%1"" se ha reemplazado por ""%2""';es_CO = 'El artículo ""%1"" se ha reemplazado por ""%2""';tr = 'Öğe ""%1"" ""%2"" ile değiştirilecek';it = 'L''elemento %1 è stato sostituito con %2';de = 'Artikel ""%1"" wird durch ""%2"" ersetzt'"),
				RefsToReplace[0].Ref,
				ReplacementItemResult);
		Else
			ResultingText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Элементы (%1) заменены на ""%2""'; en = 'Items (%1) were replaced with %2'; pl = 'Elementy (%1) zostają zastąpione przez ""%2""';es_ES = 'Artículos (%1) se han reemplazado por ""%2""';es_CO = 'Artículos (%1) se han reemplazado por ""%2""';tr = 'Öğeler (%1) ""%2"" ile değiştirilecek';it = 'L''elemento (%1) è stato sostituito con %2';de = 'Elemente (%1) werden durch ""%2"" ersetzt'"),
				Count,
				ReplacementItemResult);
		EndIf;
		ShowUserNotification(
			,
			GetURL(ReplacementItem),
			ResultingText,
			PictureLib.Information32);
		UpdatedItemsList = New Array;
		For Each Row In RefsToReplace Do
			UpdatedItemsList.Add(Row.Ref);
		EndDo;
		NotifyOfSuccessfulReplacement(UpdatedItemsList);
		Close();
	EndIf
	
EndProcedure

&AtServer
Function FillUnsuccessfulReplacements(Val ResultAddress)
	// ReplacementResults - table with the Reference, ErrorObject, ErrorType, ErrorText columns.
	ReplacementResults = GetFromTempStorage(ResultAddress);
	
	RootRows = UnsuccessfulReplacements.GetItems();
	RootRows.Clear();
	
	RowMap = New Map;
	MetadataCache     = New Map;
	
	For Each ResultString In ReplacementResults Do
		Ref = ResultString.Ref;
		
		ErrorsByReference = RowMap[Ref];
		If ErrorsByReference = Undefined Then
			TreeRow = RootRows.Add();
			TreeRow.Ref = Ref;
			TreeRow.Data = String(Ref);
			TreeRow.Code    = String( PossibleReferenceCode(Ref, MetadataCache) );
			TreeRow.Icon = -1;
			
			ErrorsByReference = TreeRow.GetItems();
			RowMap.Insert(Ref, ErrorsByReference);
		EndIf;
		
		ErrorRow = ErrorsByReference.Add();
		ErrorRow.Ref = ResultString.ErrorObject;
		ErrorRow.Data = ResultString.ErrorObjectPresentation;
		
		ErrorType = ResultString.ErrorType;
		If ErrorType = "UnknownData" Then
			ErrorRow.Reason = NStr("ru = 'Обнаружена данные, обработка которых не планировалась.'; en = 'Data not planned to be processed was found.'; pl = 'Są wykryte dane, których przetwarzanie nie było zaplanowane.';es_ES = 'Datos cuyo procesamiento no se ha programado se han detectado.';es_CO = 'Datos cuyo procesamiento no se ha programado se han detectado.';tr = 'Hangi işlemin planlanmadığı belirlendi.';it = 'Sono stati trovati dati che non era stato pianificato di processare.';de = 'Daten, deren Verarbeitung nicht geplant war, werden erkannt.'");
			
		ElsIf ErrorType = "LockError" Then
			ErrorRow.Reason = NStr("ru = 'Не удалось заблокировать данные.'; en = 'Cannot lock data.'; pl = 'Nie udało się zablokować dane.';es_ES = 'No se ha podido bloquear los datos.';es_CO = 'No se ha podido bloquear los datos.';tr = 'Veri kilitlenemedi';it = 'Non è possibile bloccare i dati.';de = 'Die Daten konnten nicht blockiert werden.'");
			
		ElsIf ErrorType = "DataChanged" Then
			ErrorRow.Reason = NStr("ru = 'Данные изменены другим пользователем.'; en = 'Data was changed by another user.'; pl = 'Dane zmienione przez innego użytkownika.';es_ES = 'Datos se han cambiado por otro usuario.';es_CO = 'Datos se han cambiado por otro usuario.';tr = 'Veri başka bir kullanıcı tarafından değiştirildi.';it = 'I dati sono stati modificati da un altro utente.';de = 'Daten werden von einem anderen Benutzer geändert.'");
			
		ElsIf ErrorType = "WritingError" Then
			ErrorRow.Reason = ResultString.ErrorText;
			
		ElsIf ErrorType = "DeletionError" Then
			ErrorRow.Reason = NStr("ru = 'Невозможно удалить данные.'; en = 'Cannot delete data.'; pl = 'Nie możesz usunąć danych.';es_ES = 'Usted no puede borrar los datos.';es_CO = 'Usted no puede borrar los datos.';tr = 'Verileri silemezsiniz.';it = 'Non è possibile eliminare i dati.';de = 'Sie können Daten nicht löschen.'");
			
		Else
			ErrorRow.Reason = NStr("ru = 'Неизвестная ошибка.'; en = 'Unknown error.'; pl = 'Nieznany błąd.';es_ES = 'Error desconocido.';es_CO = 'Error desconocido.';tr = 'Bilinmeyen hata.';it = 'Errore sconosciuto.';de = 'Unbekannter Fehler.'");
			
		EndIf;
		
		ErrorRow.DetailedReason = ResultString.ErrorText;
	EndDo; // replacement results
	
	Return RootRows.Count() > 0;
EndFunction

&AtClient
Procedure AfterConfirmCancelJob(Response, ExecutionParameters) Export
	If Response = DialogReturnCode.Abort
		AND Items.WizardSteps.CurrentPage = Items.ReplacementStep Then
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