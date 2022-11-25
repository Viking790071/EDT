// This form is parameterized.
//
// Parameters:
//     ReferenceList - Array, ValueList - a set of references to analyze.
//                                             The parameter can be a collection of objects that have the "Reference" field.
//

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Passing parameters to the UsageInstances table.
	// Initializing the MainItem, ReferencesToReplaceCommonOwner, and ParameterErrorText attributes.
	InitializeReferencesToMerge( RefArrayFromSet(Parameters.RefSet) );
	If Not IsBlankString(ParametersErrorText) Then
		// A warning will be issued on opening;
		Return;
	EndIf;
	
	ObjectMetadata = MainItem.Ref.Metadata();
	HasRightToDeletePermanently = AccessRight("DataAdministration", Metadata) 
		Or AccessRight("InteractiveDelete", ObjectMetadata);
	ReplacementNotificationEvent        = DataProcessors.ReplaceAndMergeItems.ReplacementNotificationEvent();
	
	CurrentDeletionOption = "Check";
	
	// Initialization of step-by-step wizard steps.
	InitializeStepByStepWizardSettings();
	
	// 1. Searching for usage instances by parameters.
	SearchStep = AddWizardStep(Items.SearchForUsageInstancesStep);
	SearchStep.BackButton.Visible = False;
	SearchStep.NextButton.Visible = False;
	SearchStep.CancelButton.Title = NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'");
	SearchStep.CancelButton.ToolTip = NStr("ru = 'Отказаться от объединения элементов'; en = 'Cancel item merging'; pl = 'Odmów łączenia elementów';es_ES = 'Rechazar la combinación de artículos';es_CO = 'Rechazar la combinación de artículos';tr = 'Öğeleri birleştirmeyi reddet';it = 'Annullare l''unione degli elementi';de = 'Verweigern Sie das Zusammenführen von Elementen'");
	
	// 2. Main item selection.
	Step = AddWizardStep(Items.MainItemSelectionStep);
	Step.BackButton.Visible = False;
	Step.NextButton.DefaultButton = True;
	Step.NextButton.Title = NStr("ru = 'Объединить >'; en = 'Merge >'; pl = 'Połącz >';es_ES = 'Combinar >';es_CO = 'Combinar >';tr = 'Birleştir >';it = 'Aggregare >';de = 'Zusammenführen >'");
	Step.NextButton.ToolTip = NStr("ru = 'Начать объединение элементов'; en = 'Start merging items'; pl = 'Zacznij łączyć elementy';es_ES = 'Empezar a combinar los artículos';es_CO = 'Empezar a combinar los artículos';tr = 'Öğeleri birleştirmeye başla';it = 'Iniziare unificazione elementi';de = 'Beginnen Sie mit dem Zusammenführen von Elementen'");
	Step.CancelButton.Title = NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Отказаться от объединения элементов'; en = 'Cancel item merging'; pl = 'Odmów łączenia elementów';es_ES = 'Rechazar la combinación de artículos';es_CO = 'Rechazar la combinación de artículos';tr = 'Öğeleri birleştirmeyi reddet';it = 'Annullare l''unione degli elementi';de = 'Verweigern Sie das Zusammenführen von Elementen'");
	
	// 3. Waiting for process.
	Step = AddWizardStep(Items.MergeStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.Title = NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Прервать объединение элементов'; en = 'Abort merging items'; pl = 'Zatrzymaj łączenie elementów';es_ES = 'Parar juntar los artículos';es_CO = 'Parar juntar los artículos';tr = 'Öğelere katılmayı durdur';it = 'Interrompere l''unione degli elementi';de = 'Aufhören Elemente zu verbinden'");
	
	// 4. Successful merge.
	Step = AddWizardStep(Items.SuccessfulCompletionStep);
	Step.BackButton.Visible = False;
	Step.NextButton.Visible = False;
	Step.CancelButton.DefaultButton = True;
	Step.CancelButton.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Закрыть результаты объединения'; en = 'Close merge results'; pl = 'Zamknij wyniki grupowania';es_ES = 'Cerrar los resultado de agrupación';es_CO = 'Cerrar los resultado de agrupación';tr = 'Gruplama sonuçlarını kapat';it = 'Chiudere i risultati dell''aggregazione';de = 'Schließen Sie die Gruppierungsergebnisse'");
	
	// 5. Reference replacement issues.
	Step = AddWizardStep(Items.RetryMergeStep);
	Step.BackButton.Title = NStr("ru = '< В начало'; en = '< To beginning'; pl = '< do Strony Głównej';es_ES = '< Ir a la página principal';es_CO = '< Ir a la página principal';tr = '< Başa';it = '< All''inizio';de = '< Zum Anfang'");
	Step.BackButton.ToolTip = NStr("ru = 'Вернуться к выбору основного элемента'; en = 'Return to the main item selection'; pl = 'Wróć do wyboru głównego elementu';es_ES = 'Volver a la selección principal de artículos';es_CO = 'Volver a la selección principal de artículos';tr = 'Ana öğe seçimine geri dön';it = 'Ritorna alla selezione principale dell''elemento';de = 'Gehe zurück zur Hauptelementauswahl'");
	Step.NextButton.DefaultButton = True;
	Step.NextButton.Title = NStr("ru = 'Повторить'; en = 'Retry'; pl = 'Powtórz';es_ES = 'Repetir';es_CO = 'Repetir';tr = 'Tekrarla';it = 'Riprova';de = 'Wiederholen'");
	Step.NextButton.ToolTip = NStr("ru = 'Повторить объединение'; en = 'Retry merging'; pl = 'Powtórz grupowanie';es_ES = 'Repetir la agrupación';es_CO = 'Repetir la agrupación';tr = 'Gruplamayı tekrarla';it = 'Riprovare l''unione';de = 'Wiederholen Sie die Gruppierung'");
	Step.CancelButton.Title = NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'");
	Step.CancelButton.ToolTip = NStr("ru = 'Закрыть результаты объединения'; en = 'Close merge results'; pl = 'Zamknij wyniki grupowania';es_ES = 'Cerrar los resultado de agrupación';es_CO = 'Cerrar los resultado de agrupación';tr = 'Gruplama sonuçlarını kapat';it = 'Chiudere i risultati dell''aggregazione';de = 'Schließen Sie die Gruppierungsergebnisse'");
	
	// 6. Runtime errors.
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
	
	// References replacement is a critical step that requires confirmation of cancellation.
	If WizardSettings.ShowDialogBeforeClose
		AND Items.WizardSteps.CurrentPage = Items.MergeStep Then
		
		Cancel = True;
		If Exit Then
			Return;
		EndIf;
		
		QuestionText = NStr("ru = 'Прервать объединение элементов и закрыть форму?'; en = 'Stop merging items and close the form?'; pl = 'Zaprzestać łączyć elementy i zamknąć formularz?';es_ES = '¿Parar la combinación de artículos y cerrar el formulario?';es_CO = '¿Parar la combinación de artículos y cerrar el formulario?';tr = 'Öğeleri birleştirmeyi bırak ve formu kapat?';it = 'Vuoi interrompere la unione degli elementi e chiudere il modulo?';de = 'Das Zusammenführen von Elementen beenden und das Formular schließen?'");
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort, NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'"));
		Buttons.Add(DialogReturnCode.No,      NStr("ru = 'Не прерывать'; en = 'Do not stop'; pl = 'Nie przerywać';es_ES = 'No interrumpir';es_CO = 'No interrumpir';tr = 'Kesme';it = 'Non fermare';de = 'Nicht unterbrechen'"));
		
		Handler = New NotifyDescription("AfterConfirmCancelJob", ThisObject);
		ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.No);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderEventHandlers

&AtClient
Procedure MainItemSelectionTooltipURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	If FormattedStringURL = "SwitchDeletionMode" Then
		If CurrentDeletionOption = "Directly" Then
			CurrentDeletionOption = "Check" 
		Else
			CurrentDeletionOption = "Directly" 
		EndIf;
		GenerateMergeTooltip();
	EndIf;
	
EndProcedure

&AtClient
Procedure DetailsRefClick(Item)
	StandardSubsystemsClient.ShowDetailedInfo(Undefined, Item.ToolTip);
EndProcedure

#EndRegion

#Region UsageInstancesFormTableItemsEventHandlers

&AtClient
Procedure UsageInstancesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	Ref = UsageInstances.FindByID(RowSelected).Ref;
	
	If Field <> Items.UsageInstancesUsageCount Then
		ShowValue(, Ref);
		Return;
	EndIf;
	
	RefSet = New Array;
	RefSet.Add(Ref);
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(RefSet);
	
EndProcedure

&AtClient
Procedure UsageInstancesBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	If Clone Then
		Return;
	EndIf;
	
	// Always add an item of the same type as the main one.
	ChoiceFormName = SelectionFormNameByReference(MainItem);
	If Not IsBlankString(ChoiceFormName) Then
		FormParameters = New Structure("MultipleChoice", True);
		If ReferencesToReplaceCommonOwner <> Undefined Then
			FormParameters.Insert("Filter", New Structure("Owner", ReferencesToReplaceCommonOwner));
		EndIf;
		OpenForm(ChoiceFormName, FormParameters, Item);
	EndIf;
EndProcedure

&AtClient
Procedure UsageInstancesBeforeDelete(Item, Cancel)
	Cancel = True;
	
	CurrentData = Item.CurrentData;
	If CurrentData=Undefined Or UsageInstances.Count()<3 Then
		Return;
	EndIf;
	
	Ref = CurrentData.Ref;
	Code    = String(CurrentData.Code);
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Удалить из списка для объединения элемент ""%1""?'; en = 'Delete item ""%1"" from the list to merge?'; pl = 'Usunąć element ""%1"" z listy do połączenia?';es_ES = '¿Borrar el artículo ""%1"" de la lista para combinar?';es_CO = '¿Borrar el artículo ""%1"" de la lista para combinar?';tr = 'Öğe ""%1"" yenileme listesinden silinsin mi?';it = 'Cancellare l''elemento ""%1"" dall''elenco di unione?';de = 'Element ""%1"" aus der Liste zum Zusammenführen löschen?'"),
		String(Ref) + ?(IsBlankString(Code), "", " (" + Code + ")" ));
	
	Notification = New NotifyDescription("UsageInstancesBeforeDeleteCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("CurrentRow", Item.CurrentRow);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure UsageInstancesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		ItemsToAdd = ValueSelected;
	Else
		ItemsToAdd = New Array;
		ItemsToAdd.Add(ValueSelected);
	EndIf;
	
	AddUsageInstancesRows(ItemsToAdd);
	GenerateMergeTooltip();
EndProcedure

#EndRegion

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
Procedure OpenUsageInstancesItem(Command)
	CurrentData = Items.UsageInstances.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure UsageInstances(Command)
	
	CurrentData = Items.UsageInstances.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	RefSet = New Array;
	RefSet.Add(CurrentData.Ref);
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(RefSet);
	
EndProcedure

&AtClient
Procedure AllUsageInstances(Command)
	
	If UsageInstances.Count() > 0 Then 
		FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(UsageInstances);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAsMain(Command)
	CurrentData = Items.UsageInstances.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	MainItem = CurrentData.Ref;
	GenerateMergeTooltip();
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
	
	If CurrentPage = Items.SearchForUsageInstancesStep Then
		
		RunBackgroundJobClient();
		
	ElsIf CurrentPage = Items.MainItemSelectionStep Then
		
		GenerateMergeTooltip();
		
	ElsIf CurrentPage = Items.MergeStep Then
		
		WizardSettings.ShowDialogBeforeClose = True;
		RunBackgroundJobClient();
		
	ElsIf CurrentPage = Items.SuccessfulCompletionStep Then
		
		Items.MergeResult.Title = CompleteMessage() + " """ + String(MainItem) + """";
		
		UpdatedItemsList = New Array;
		For Each Row In UsageInstances Do
			UpdatedItemsList.Add(Row.Ref);
		EndDo;
		NotifyOfSuccessfulReplacement(UpdatedItemsList);
		
	ElsIf CurrentPage = Items.RetryMergeStep Then
		
		// Refreshing number of failures.
		GenerateUnsuccessfulReplacementLabel();
		
		// Notifying of partial successful replacement.
		UpdatedItemsList = DeleteProcessedItemsFromUsageInstances();	// Deleting the item from the list of options.
		NotifyOfSuccessfulReplacement(UpdatedItemsList);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepNext()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.MainItemSelectionStep Then
		
		ErrorText = CheckCanReplaceReferences();
		If Not IsBlankString(ErrorText) Then
			StandardSubsystemsClient.ShowQuestionToUser(Undefined, 
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Невозможно объединить элементы по причине:
					|%1'; 
					|en = 'Cannot merge items due to:
					|%1'; 
					|pl = 'Nie można połączyć elementy z powodu:
					|%1';
					|es_ES = 'Es imposible unir los elementos a causa:
					|%1';
					|es_CO = 'Es imposible unir los elementos a causa:
					|%1';
					|tr = 'Aşağıdaki nedenden dolayı nesneler birleştirilemedi: 
					|%1';
					|it = 'Impossibile aggregare gli elementi a causa:
					| %1';
					|de = 'Elemente können nicht zusammengeführt werden, weil:
					|%1'"), ErrorText), QuestionDialogMode.OK);
			Return;
		EndIf;
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	ElsIf CurrentPage = Items.RetryMergeStep Then
		
		GoToWizardStep(Items.MergeStep);
		
	Else
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepBack()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.RetryMergeStep Then
		
		GoToWizardStep(Items.SearchForUsageInstancesStep);
		
	Else
		
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf - 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WizardStepCancel()
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.MergeStep Then
		
		WizardSettings.ShowDialogBeforeClose = False;
		
	EndIf;
	
	If IsOpen() Then
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal merge items procedures

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesMain.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = New DataCompositionField("MainItem");

	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesRef.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesCode.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesUsageCount.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New DataCompositionField("MainItem");

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesNotUsed.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", True);
	Item.Appearance.SetParameterValue("Show", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesNotUsed.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesUsageCount.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UnsuccessfulReplacementsCode.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UnsuccessfulReplacements.Code");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsageInstancesUsageCount.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsageInstances.UsageInstancesCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Visible", True);
	Item.Appearance.SetParameterValue("Show", True);

EndProcedure

&AtServer
Procedure InitializeReferencesToMerge(Val RefsArray)
	
	CheckResult = CheckReferencesToMerge(RefsArray);
	ParametersErrorText = CheckResult.Error;
	If Not IsBlankString(ParametersErrorText) Then
		Return;
	EndIf;
	
	MainItem = RefsArray[0];
	ReferencesToReplaceCommonOwner = CheckResult.CommonOwner;
	
	UsageInstances.Clear();
	For Each Item In RefsArray Do
		UsageInstances.Add().Ref = Item;
	EndDo;
EndProcedure

&AtServerNoContext
Function CheckReferencesToMerge(Val RefSet)
	
	Result = New Structure("Error, CommonOwner");
	
	RefsCount = RefSet.Count();
	If RefsCount < 2 Then
		Result.Error = NStr("ru = 'Для объединения необходимо указать несколько элементов.'; en = 'Select more then one item to merge.'; pl = 'Określ kilka elementów do połączenia.';es_ES = 'Especificar varios artículos para combinar.';es_CO = 'Especificar varios artículos para combinar.';tr = 'Birleştirme için birkaç öğe belirtin.';it = 'Per effettuare l''aggregazione è necessario indicare più elementi.';de = 'Geben Sie mehrere Elemente zum Zusammenführen an.'");
		Return Result;
	EndIf;
	
	FirstItem = RefSet[0];
	
	BasicMetadata = FirstItem.Metadata();
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
	Query = New Query("
		|SELECT Ref AS Ref" + AdditionalFields + " INTO RefsToReplace
		|FROM " + TableName + " WHERE Ref IN (&RefSet)
		|INDEX BY Owner, IsFolder
		|;
		|SELECT 
		|	COUNT(DISTINCT Owner) AS OwnersCount,
		|	MIN(Owner)              AS CommonOwner,
		|	MAX(IsFolder)            AS HasGroups,
		|	COUNT(Ref)             AS RefsCount
		|FROM
		|	RefsToReplace
		|");
	Query.SetParameter("RefSet", RefSet);
	
	Control = Query.Execute().Unload()[0];
	If Control.HasGroups Then
		Result.Error = NStr("ru = 'Один из объединяемых элементов является группой.
		                              |Группы не могут быть объединены.'; 
		                              |en = 'One of the items to merge is a group.
		                              |Groups cannot be merged.'; 
		                              |pl = 'Jeden z łączonych elementów jest grupą
		                              |Grupy nie mogą być połączone.';
		                              |es_ES = 'Uno de los artículos combinados es un grupo.
		                              |Los grupos no pueden combinarse.';
		                              |es_CO = 'Uno de los artículos combinados es un grupo.
		                              |Los grupos no pueden combinarse.';
		                              |tr = 'Birleştirilmiş öğelerden biri bir gruptur. 
		                              |Gruplar birleştirilemez.';
		                              |it = 'Uno degli elementi aggregati è un gruppo.
		                              | Gruppi non possono essere aggregati.';
		                              |de = 'Eines der zusammengeführten Elemente ist eine Gruppe.
		                              |Die Gruppen können nicht zusammengeführt werden.'");
	ElsIf Control.OwnersCount > 1 Then 
		Result.Error = NStr("ru = 'У объединяемых элементов различные владельцы.
		                              |Такие элементы не могут быть объединены.'; 
		                              |en = 'Items to merge have different owners. 
		                              |Such items cannot be merged.'; 
		                              |pl = 'Łączone elementy mają różnych właścicieli.
		                              |Takie elementy nie mogą być połączone.';
		                              |es_ES = 'Artículos combinados tienen diferentes propietarios.
		                              |Estos artículos no pueden combinarse.';
		                              |es_CO = 'Artículos combinados tienen diferentes propietarios.
		                              |Estos artículos no pueden combinarse.';
		                              |tr = 'Birleştirilmiş öğelerin farklı sahipleri var. 
		                              |Bu tür maddeler birleştirilemez.';
		                              |it = 'Gli elementi aggregati hanno diversi proprietari.
		                              | Tali elementi non possono essere aggregati.';
		                              |de = 'Zusammengeführte Artikel haben unterschiedliche Besitzer.
		                              |Solche Elemente können nicht zusammengeführt werden.'");
	ElsIf Control.RefsCount <> RefsCount Then
		Result.Error = NStr("ru = 'Все объединяемые элементы должны быть одного типа.'; en = 'All items to merge must be of the same type.'; pl = 'Wszystkie elementy łączone muszą być tego samego typu.';es_ES = 'Todos los artículos combinables tienen que ser del mismo tipo.';es_CO = 'Todos los artículos combinables tienen que ser del mismo tipo.';tr = 'Tüm birleştirilebilir öğeler aynı tipte olmalıdır.';it = 'Tutti gli elementi aggregati devono essere dello stesso tipo.';de = 'Alle zusammengeführten Elemente müssen vom gleichen Typ sein.'");
	Else 
		// Successfully
		Result.CommonOwner = ?(HasOwners, Control.CommonOwner, Undefined);
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure UsageInstancesBeforeDeleteCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	// Actual deletion from the table.
	Row = UsageInstances.FindByID(AdditionalParameters.CurrentRow);
	If Row = Undefined Then
		Return;
	EndIf;
	
	DeletedRowIndex = UsageInstances.IndexOf(Row);
	CalculateMain     = Row.Ref = MainItem;
	
	UsageInstances.Delete(Row);
	If CalculateMain Then
		LastStringIndex = UsageInstances.Count() - 1;
		If DeletedRowIndex <= LastStringIndex Then 
			MainStringIndex = DeletedRowIndex;
		Else
			MainStringIndex = LastStringIndex;
		EndIf;
			
		MainItem = UsageInstances[MainStringIndex].Ref;
	EndIf;
	
	GenerateMergeTooltip();
EndProcedure

&AtServer
Procedure GenerateMergeTooltip()

	If HasRightToDeletePermanently Then
		If CurrentDeletionOption = "Check" Then
			TooltipText = NStr("ru = 'Элементы (%1) будут <a href = ""SwitchDeletionMode"">помечены на удаление</a> и заменены во всех местах
				|использования на ""%2"" (отмечен стрелкой).'; 
				|en = 'Items (%1) will be <a href = ""SwitchDeletionMode"">marked for deletion</a> and replaced in all usage instances 
				|with ""%2"" (marked with an arrow).'; 
				|pl = 'Elementy (%1) będą <a href = ""SwitchDeletionMode"">oznaczone do usunięcia</a> i zastąpione we wszystkich miejscach użycia 
				|""%2"" (zaznaczony strzałką).';
				|es_ES = 'Artículos (%1) estarán <a href = ""SwitchDeletionMode"">marcados para deletion</a> y reemplazados en todos los sitios del uso
				|con %2 (marcado con una flecha).';
				|es_CO = 'Artículos (%1) estarán <a href = ""SwitchDeletionMode"">marcados para deletion</a> y reemplazados en todos los sitios del uso
				|con %2 (marcado con una flecha).';
				|tr = 'Öğeler (%1), <a href = ""SwitchDeletionMode""> silinmek üzere işaretlenmiş</a> olacaktır ve (okla işaretlenmiş) tüm kullanım 
				| yerlerinde ''''%2'''' ile değiştirilecektir.';
				|it = 'L''elemento (%1) sarà <a href = ""SwitchDeletionMode"">contrassegnato per l''eliminazione</a>, e sostituito in tutte i contesti d''uso 
				|con ""%2"" (contrassegnato con una freccia).';
				|de = 'Elemente (%1) werden <a href = ""SwitchDeletionMode"">zum Löschen
				|markiert</a> und an allen Verwendungsstellen ersetzt durch %2 (mit einem Pfeil gekennzeichnet).'");
		Else
			TooltipText = NStr("ru = 'Элементы (%1) будут <a href = ""SwitchDeletionMode"">удалены безвозвратно</a> и заменены во всех местах
				|использования на ""%2"" (отмечен стрелкой).'; 
				|en = 'Items (%1) will be <a href = ""SwitchDeletionMode"">permanently deleted</a> and replaced in all usage instances
				| with ""%2"" (marked with an arrow).'; 
				|pl = 'Elementy (%1) będą <a href = ""SwitchDeletionMode"">trwale usunięte</a> i zastąpione zastąpione we wszystkich miejscach użycia
				| ""%2"" (zaznaczony strzałką).';
				|es_ES = 'Los elementos (%1) estarán <a href = ""SwitchDeletionMode"">borrados para siempre</a> y reemplazados en todos los sitios
				|del uso con ""%2"" (marcado con una flecha).';
				|es_CO = 'Los elementos (%1) estarán <a href = ""SwitchDeletionMode"">borrados para siempre</a> y reemplazados en todos los sitios
				|del uso con ""%2"" (marcado con una flecha).';
				|tr = 'Öğeler (%1), <a href = ""SwitchDeletionMode""> kalıcı olarak silinecek </a> ve tüm kullanım yerlerinde
				| (okla işaretlenmiş) ''''%2'''' ile değiştirilecektir.';
				|it = 'L''elemento (%1) sarà <a href = ""SwitchDeletionMode"">eliminato in modo permanente</a> e sostituito in tutti i contesti d''uso
				| con""%2"" (contrassegnato con una freccia).';
				|de = 'Die Elemente (%1) werden <a href = ""SwitchDeletionMode"">unwiderruflich gelöscht</a> und an allen
				|Verwendungsorten durch ""%2"" (mit einem Pfeil markiert) ersetzt.'");
		EndIf;
	Else
		TooltipText = NStr("ru = 'Элементы (%1) будут помечены на удаление и заменены во всех местах
			|использования на ""%2"" (отмечен стрелкой).'; 
			|en = 'Items (%1) will be marked for deletion and replaced in all usage
			|instances with ""%2"" (marked with an arrow).'; 
			|pl = 'Elementy (%1) będą oznaczone do usunięcia i wymienione we wszystkich miejscach
			|wykorzystania na ""%2"" (zaznaczony strzałką).';
			|es_ES = 'Los elementos (%1) se marcarán para borrar y se reemplazarán en todos los sitios
			|del uso con ""%2"" (marcado con una flecha).';
			|es_CO = 'Los elementos (%1) se marcarán para borrar y se reemplazarán en todos los sitios
			|del uso con ""%2"" (marcado con una flecha).';
			|tr = 'Öğeler (%1) silinmek üzere işaretlenecek ve (okla işaretlenmiş) tüm kullanım %2 yerlerinde 
			| ile değiştirilecektir.';
			|it = 'L''elemento (%1) sarà contrassegnato per l''eliminazione e sostituito in tutti i contesti
			|d''uso con ""%2"" (contrassegnato con una freccia).';
			|de = 'Die Elemente (%1) werden zum Löschen markiert und an allen
			|Verwendungsorten durch ""%2"" (mit einem Pfeil markiert) ersetzt.'");
	EndIf;
		
	TooltipText = StringFunctionsClientServer.SubstituteParametersToString(TooltipText, UsageInstances.Count()-1, MainItem);
	Items.MainItemSelectionTooltip.Title = StringFunctionsClientServer.FormattedString(TooltipText);
	
EndProcedure

&AtClient
Function CompleteMessage()
	Return StringFunctionsClientServer.StringWithNumberForAnyLanguage(
		NStr("ru = ';%1 элемент объединен в:;;%1 элемента объединено в:;%1 элементов объединено в:;%1 элемента объединено в:'; en = ';%1 item was merged into:;;%1 items were merged into:;%1 items were merged into:;%1 items were merged into:'; pl = ';%1 element połączony w:;;%1 elementy połączone w:;%1 elementów połączono w:;%1 elementy połączono w:';es_ES = ';%1 elemento unido en:;;%1 del elemento unido en:;%1 de los elementos unidos en:;%1 del elemento unido en:';es_CO = ';%1 elemento unido en:;;%1 del elemento unido en:;%1 de los elementos unidos en:;%1 del elemento unido en:';tr = ';%1 öğe birleştirildi:;;%1 öğe birleştirildi:;%1 öğe birleştirildi:;%1 öğe birleştirildi:';it = ';%1 elemento è stato unito in:;;%1 elementi sono stati uniti in:;%1 elementi sono stati uniti in:;%1 elementi sono stati uniti in:';de = ';%1 Das Element ist in das Folgende geschmolzen:;;%1 Die Elemente sind in das Folgende geschmolzen:;%1 Die Elemente sind in das Folgende geschmolzen:;%1 Die Elemente sind in das Folgende geschmolzen:'"),
		UsageInstances.Count());
EndFunction

&AtClient
Procedure GenerateUnsuccessfulReplacementLabel()
	
	Items.UnsuccessfulReplacementsResult.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Объединение элементов не выполнено. В некоторых местах использования не может быть произведена
		           |автоматическая замена на ""%1""'; 
		           |en = 'Cannot merge items. In some usage instances, items cannot be automatically replaced
		           |with ""%1""'; 
		           |pl = 'Łączenie elementów nie zostało wykonane. W niektórych miejscach użytkowania nie może być wykonana
		           | automatyczna wymiana na ""%1""';
		           |es_ES = 'Combinación de elementos no se ha ejecutado. En algunos sitios del uso un reemplazo
		           |automático con ""%1"" no puede ejecutarse';
		           |es_CO = 'Combinación de elementos no se ha ejecutado. En algunos sitios del uso un reemplazo
		           |automático con ""%1"" no puede ejecutarse';
		           |tr = 'Öğeler birleştirilemedi. Bazı yerlerde 
		           |otomatik yer değiştirme %1 ile çalıştırılamaz.';
		           |it = 'Impossibile unire gli elementi. In qualche contesto d''uso gli elementi non possono essere sostituiti automaticamente
		           |con ""%1""';
		           |de = 'Die Elemente wurden nicht zusammengeführt. In einigen Anwendungsbereichen kann das
		           |automatische Ersetzen durch ""%1"" nicht durchgeführt werden'"),
		MainItem);
	
EndProcedure

// Parameters:
//     DataList - Array - contains changed data; its type will be shown as a notification.
//
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
	If TypesList.Count() > 0 Then
		Notify(ReplacementNotificationEvent, , ThisObject);
	EndIf;
EndProcedure

&AtServerNoContext
Function SelectionFormNameByReference(Val Ref)
	Meta = Metadata.FindByType(TypeOf(Ref));
	Return ?(Meta = Undefined, Undefined, Meta.FullName() + ".ChoiceForm");
EndFunction

// Converts an array, list of values, or collection to an array.
//
&AtServerNoContext
Function RefArrayFromSet(Val References)
	
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

// Adds an array of references
&AtServer
Procedure AddUsageInstancesRows(Val RefsArray)
	LastItemIndex = Undefined;
	MetadataCache    = New Map;
	
	Filter = New Structure("Ref");
	For Each Ref In RefsArray Do
		Filter.Ref = Ref;
		ExistingRows = UsageInstances.FindRows(Filter);
		If ExistingRows.Count() = 0 Then
			Row = UsageInstances.Add();
			Row.Ref = Ref;
			
			Row.Code      = PossibleReferenceCode(Ref, MetadataCache);
			Row.Owner = PossibleReferenceOwner(Ref, MetadataCache);
			
			Row.UsageInstancesCount = -1;
			Row.NotUsed    = NStr("ru = 'Не рассчитано'; en = 'Not calculated'; pl = 'Nie rozliczone';es_ES = 'No calculado';es_CO = 'No calculado';tr = 'Hesaplanmadı';it = 'Non calcolato';de = 'Nicht berechnet'");
		Else
			Row = ExistingRows[0];
		EndIf;
		
		LastItemIndex = Row.GetID();
	EndDo;
	
	If LastItemIndex <> Undefined Then
		Items.UsageInstances.CurrentRow = LastItemIndex;
	EndIf;
EndProcedure

// Returns:
//     Arbitrary - catalog code and so on if metadata has a code,
//     Undefined if there is no code.
//
&AtServerNoContext
Function PossibleReferenceCode(Val Ref, MetadataCache)
	Data = MetaDetailsByReference(Ref, MetadataCache);
	Return ?(Data.HasCode, Ref.Code, Undefined);
EndFunction

// Returns:
//     Arbitrary - catalog owner if it exists according to metadata,
//     Undefined if there is no owner.
//
&AtServerNoContext
Function PossibleReferenceOwner(Val Ref, MetadataCache)
	Data = MetaDetailsByReference(Ref, MetadataCache);
	Return ?(Data.HasOwner, Ref.Owner, Undefined);
EndFunction

// Returns catalog description according to metadata.
&AtServerNoContext
Function MetaDetailsByReference(Val Ref, MetadataCache)
	
	ObjectMetadata = Ref.Metadata();
	Data = MetadataCache[ObjectMetadata];
	
	If Data = Undefined Then
		Test = New Structure("CodeLength, Owners", 0, New Array);
		FillPropertyValues(Test, ObjectMetadata);
		
		Data = New Structure;
		Data.Insert("HasCode", Test.CodeLength > 0);
		Data.Insert("HasOwner", Test.Owners.Count() > 0);
		
		MetadataCache[ObjectMetadata] = Data;
	EndIf;
	
	Return Data;
EndFunction

// Returns a list of successfully replaced references that are not in UnsuccessfulReplacements.
&AtClient
Function DeleteProcessedItemsFromUsageInstances()
	Result = New Array;
	
	Unsuccessful = New Map;
	For Each Row In UnsuccessfulReplacements.GetItems() Do
		Unsuccessful.Insert(Row.Ref, True);
	EndDo;
	
	Index = UsageInstances.Count() - 1;
	While Index > 0 Do
		Ref = UsageInstances[Index].Ref;
		If Ref<>MainItem AND Unsuccessful[Ref] = Undefined Then
			UsageInstances.Delete(Index);
			Result.Add(Ref);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Return Result;
EndFunction

// Checking whether items can be replaced in terms of applied data.
&AtServer
Function CheckCanReplaceReferences()
	
	RefSet = New Array;
	ReplacementPairs   = New Map;
	For Each Row In UsageInstances Do
		RefSet.Add(Row.Ref);
		ReplacementPairs.Insert(Row.Ref, MainItem);
	EndDo;
	
	// Checking once again, the set might be modified.
	Control = CheckReferencesToMerge(RefSet);
	If Not IsBlankString(Control.Error) Then
		Return Control.Error;
	EndIf;
	
	ReplacementParameters = New Structure("DeletionMethod", CurrentDeletionOption);
	Return DuplicateObjectDetection.CheckCanReplaceItemsString(ReplacementPairs, ReplacementParameters);
	
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
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.SearchForUsageInstancesStep Then
		
		MethodName = "DuplicateObjectDetection.DefineUsageInstances";
		MethodDescription = NStr("ru = 'Поиск и удаление дублей: Определение мест использования'; en = 'Duplicates search and deletion: Determine usage instances'; pl = 'Wyszukiwanie i usuwanie duplikatów: Określenie lokalizacji użycia';es_ES = 'Buscar y borrar los duplicados: Determinas las ubicaciones de uso';es_CO = 'Buscar y borrar los duplicados: Determinas las ubicaciones de uso';tr = 'Çiftlerin aranması ve silinmesi: Kullanım konumlarını belirleme';it = 'Ricerca e cancellazione dei duplicati: Determinare contesti d''uso';de = 'Suchen und Löschen von Duplikaten: Bestimmen Sie Verwendungsorte'");
		MethodParameters = RefArrayFromSet(UsageInstances);
		
	ElsIf CurrentPage = Items.MergeStep Then
		
		MethodName = "DuplicateObjectDetection.ReplaceReferences";
		MethodDescription = NStr("ru = 'Поиск и удаление дублей: Объединение элементов'; en = 'Duplicates search and deletion: Merge items'; pl = 'Wyszukiwanie i usuwanie duplikatów: łączenie elementów';es_ES = 'Buscar y borrar los duplicados: Combinar los artículos';es_CO = 'Buscar y borrar los duplicados: Combinar los artículos';tr = 'Çiftlerin aranması ve silinmesi: Öğeleri birleştir';it = 'Ricerca e cancellazione dei duplicati: Unire elementi';de = 'Suchen und Löschen von Duplikaten: Elemente zusammenführen'");
		MethodParameters = New Structure("ReplacementPairs, Parameters");
		MethodParameters.ReplacementPairs = New Map;
		For Each Row In UsageInstances Do
			MethodParameters.ReplacementPairs.Insert(Row.Ref, MainItem);
		EndDo;
		MethodParameters.Parameters = New Structure;
		MethodParameters.Parameters.Insert("DeletionMethod", CurrentDeletionOption);
		MethodParameters.Parameters.Insert("IncludeBusinessLogic", True);
		MethodParameters.Parameters.Insert("ReplacePairsInTransaction", False);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = MethodDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings);
EndFunction

&AtClient
Procedure AfterCompleteBackgroundJob(Job, AdditionalParameters) Export
	WizardSettings.ShowDialogBeforeClose = False;
	
	If Job.Status <> "Completed" Then
		BriefDescription = NStr("ru = 'При замене элементов возникла ошибка:'; en = 'An error occurred while replacing items:'; pl = 'Podczas wymiany elementów wystąpił błąd:';es_ES = 'Ha ocurrido un error al reemplazar los elementos:';es_CO = 'Ha ocurrido un error al reemplazar los elementos:';tr = 'Nesne alışverişinde hata oluştu:';it = 'Un errore si è registrato durante la sostituzione elementi:';de = 'Beim Ersetzen von Elementen ist ein Fehler aufgetreten:'") + Chars.LF + Job.BriefErrorPresentation;
		More = BriefDescription + Chars.LF + Chars.LF + Job.DetailedErrorPresentation;
		Items.ErrorTextLabel.Title = BriefDescription;
		Items.DetailsRef.ToolTip    = More;
		GoToWizardStep(Items.ErrorOccurredStep);
		Activate();
		Return;
	EndIf;
	
	CurrentPage = Items.WizardSteps.CurrentPage;
	
	If CurrentPage = Items.SearchForUsageInstancesStep Then
		
		FillUsageInstances(Job.ResultAddress);
		Activate();
		GoToWizardStep(WizardSettings.CurrentStep.IndexOf + 1);
		
	ElsIf CurrentPage = Items.MergeStep Then
		
		HasUnsuccessfulReplacements = FillUnsuccessfulReplacements(Job.ResultAddress);
		If HasUnsuccessfulReplacements Then
			// Partially successful - display details.
			GoToWizardStep(Items.RetryMergeStep);
			Activate();
		Else
			// Completely successful - display notification and close the form.
			ShowUserNotification(
				CompleteMessage(),
				GetURL(MainItem),
				String(MainItem),
				PictureLib.Information32);
			UpdatedItemsList = New Array;
			For Each Row In UsageInstances Do
				UpdatedItemsList.Add(Row.Ref);
			EndDo;
			NotifyOfSuccessfulReplacement(UpdatedItemsList);
			Close();
		EndIf
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillUsageInstances(Val ResultAddress)
	UsageTable = GetFromTempStorage(ResultAddress);
	
	NewUsageInstances = UsageInstances.Unload();
	NewUsageInstances.Indexes.Add("Ref");
	
	IsUpdate = NewUsageInstances.Find(MainItem, "Ref") <> Undefined;
	
	If Not IsUpdate Then
		NewUsageInstances = UsageInstances.Unload(New Array);
		NewUsageInstances.Indexes.Add("Ref");
	EndIf;
	
	MetadataCache = New Map;
	
	MaxReference = Undefined;
	MaxInstances   = -1;
	For Each Row In UsageTable Do
		Ref = Row.Ref;
		
		UsageRow = NewUsageInstances.Find(Ref, "Ref");
		If UsageRow = Undefined Then
			UsageRow = NewUsageInstances.Add();
			UsageRow.Ref = Ref;
		EndIf;
		
		Instances = Row.Occurrences;
		If Instances>MaxInstances
			AND Not Ref.DeletionMark Then
			MaxReference = Ref;
			MaxInstances   = Instances;
		EndIf;
		
		UsageRow.UsageInstancesCount = Instances;
		UsageRow.Code      = PossibleReferenceCode(Ref, MetadataCache);
		UsageRow.Owner = PossibleReferenceOwner(Ref, MetadataCache);
		
		UsageRow.NotUsed = ?(Instances = 0, NStr("ru = 'Не используется'; en = 'Not used'; pl = 'Nie wykorzystuje się';es_ES = 'No utilizado';es_CO = 'No utilizado';tr = 'Kullanılmadı';it = 'Non usato';de = 'Nicht benutzt'"), "");
	EndDo;
	
	UsageInstances.Load(NewUsageInstances);
	
	If MaxReference <> Undefined Then
		MainItem = MaxReference;
	EndIf;
	
	// Refreshing headings
	Presentation = ?(MainItem = Undefined, "", MainItem.Metadata().Presentation());
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Объединение элементов %1 в один'; en = 'Merging %1 items into the single one'; pl = 'Połącz elementów %1 w jeden';es_ES = 'Combinar los artículos de %1 en uno solo';es_CO = 'Combinar los artículos de %1 en uno solo';tr = 'Öğeleri tek bir öğeye birleştirme %1';it = 'Unione di %1 elementi in uno';de = 'Führen Sie Elemente von %1 zu einem einzigen zusammen'"), Presentation);
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
	EndDo;
	
	Return RootRows.Count() > 0;
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