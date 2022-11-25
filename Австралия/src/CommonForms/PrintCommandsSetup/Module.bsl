
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Filter = Parameters.Filter;
	
	If Filter.Count() > 0 Then
		Items.PrintCommands.InitialTreeView = InitialTreeView.ExpandAllLevels;
	EndIf;
	
	FillPrintCommandsList();
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Title", NStr("ru ='ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("BeforeCloseConfirmationReceived", ThisObject);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit,, WarningText);
	
EndProcedure

#EndRegion

#Region PrintCommandsFormTableItemsEventHandlers

&AtClient
Procedure PrintCommandsVisibilityOnChange(Item)
	OnChangeCheckBox(Items.PrintCommands, "Visible");
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command = Undefined)
	Write();
	Close();
EndProcedure

&AtClient
Procedure ShowInList(Command)
	
	If Modified Then
		Notification = New NotifyDescription("ShowInListCompletion", ThisObject, Parameters);
		QuestionText = NStr("ru = 'Данные были изменены. Сохранить изменения?'; en = 'The data was changed. Do you want to save the changes?'; pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Volete salvare le modifiche?';de = 'Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel, ,
			DialogReturnCode.Cancel);
		Return;
	EndIf;
	
	GoToList();
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	FillCollectionAttributeValue(PrintCommands, "Visible", True);
	Modified = True;
EndProcedure

&AtClient
Procedure ClearAll(Command)
	FillCollectionAttributeValue(PrintCommands, "Visible", False);
	Modified = True;
EndProcedure

&AtClient
Procedure ApplyDefaultSettings(Command)
	FillPrintCommandsList();
	Modified = False;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshCommandsOwnerCheckBox(CommandsOwner)
	HasSelectedItems = False;
	SelectedAllItems = True;
	For Each PrintCommand In CommandsOwner.GetItems() Do
		HasSelectedItems = HasSelectedItems Or PrintCommand.Visible;
		SelectedAllItems = SelectedAllItems AND PrintCommand.Visible;
	EndDo;
	CommandsOwner.Visible = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllItems), HasSelectedItems);
EndProcedure

&AtClient
Procedure PrintCommandsChoice(Item, RowSelected, Field, StandardProcessing)
	If Field.Name = Items.PrintCommandsComment.Name 
		AND Not IsBlankString(Items.PrintCommands.CurrentData.URL) Then
			CommonClient.OpenURL(Items.PrintCommands.CurrentData.URL);
	EndIf;
EndProcedure

&AtServer
Procedure WriteCommandsSettings()
	RecordSet = InformationRegisters.PrintCommandsSettings.CreateRecordSet();
	For Each CommandsSet In PrintCommands.GetItems() Do
		RecordSet.Filter.Owner.Set(CommandsSet.Owner);
		RecordSet.Read();
		RecordSet.Clear();
		SettingsToWrite = RecordSet.Unload();
		For Each Setting In CommandsSet.GetItems() Do
			FillPropertyValues(SettingsToWrite.Add(), Setting);
		EndDo;
		SettingsToWrite.GroupBy("Owner,UUID", "Visible");
		RecordSet.Load(SettingsToWrite);
		RecordSet.Write();
	EndDo;
	Modified = False;
EndProcedure

&AtClient
Procedure OnChangeCheckBox(FormTree, CheckBoxName)
	
	CurrentData = FormTree.CurrentData;
	
	If CurrentData[CheckBoxName] = 2 Then
		CurrentData[CheckBoxName] = 0;
	EndIf;
	
	Mark = CurrentData[CheckBoxName];
	
	// Updating subordinate check boxes.
	For Each SubordinateAttribute In CurrentData.GetItems() Do
		SubordinateAttribute[CheckBoxName] = Mark;
	EndDo;
	
	// Updating a parent check box.
	Parent = CurrentData.GetParent();
	If Parent <> Undefined Then
		HasSelectedItems = False;
		SelectedAllItems = True;
		For Each Item In Parent.GetItems() Do
			HasSelectedItems = HasSelectedItems Or Item[CheckBoxName];
			SelectedAllItems = SelectedAllItems AND Item[CheckBoxName];
		EndDo;
		Parent[CheckBoxName] = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllItems), HasSelectedItems);
	EndIf;

EndProcedure

&AtClient
Procedure FillCollectionAttributeValue(Collection, AttributeName, Value)
	For Each Item In Collection.GetItems() Do
		Item[AttributeName] = Value;
		FillCollectionAttributeValue(Item, AttributeName, Value);
	EndDo;
EndProcedure

&AtServer
Procedure FillPrintCommandsList()
	
	SetPrivilegedMode(True);
	PrintCommandsSources = PrintManagement.PrintCommandsSources();
	
	PrintCommands.GetItems().Clear();
	For Each PrintCommandsSource In PrintCommandsSources Do
		PrintCommandsSourceID = Common.MetadataObjectID(PrintCommandsSource);
		If Filter.Count() > 0 AND Filter.FindByValue(PrintCommandsSourceID) = Undefined Then
			Continue;
		EndIf;
		
		ObjectPrintCommands = PrintManagement.ObjectPrintCommands(PrintCommandsSource);
		
		ObjectPrintCommands.Columns.Add("Owner");
		ObjectPrintCommands.FillValues(PrintCommandsSourceID, "Owner");
		
		ObjectPrintCommands.Columns.Add("IsExternalPrintCommand");
		For Each PrintCommand In ObjectPrintCommands Do
			PrintCommand.IsExternalPrintCommand = PrintCommand.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors";
		EndDo;
		
		If ObjectPrintCommands.Count() = 0 Then
			Continue;
		EndIf;
		
		SourceDetails = PrintCommands.GetItems().Add();
		SourceDetails.Owner = PrintCommandsSourceID;
		SourceDetails.Presentation = Common.ObjectAttributeValue(PrintCommandsSourceID, "Synonym");
		SourceDetails.Visible = 2;
		SourceDetails.URL = "e1cib/list/" + PrintCommandsSourceID.FullName;
		
		For Each PrintCommand In ObjectPrintCommands Do
			If PrintCommand.Picture.Type = PictureType.Empty Then
				PrintCommand.Picture = PictureLib.Empty;
			EndIf;
			PrintCommandDetails = SourceDetails.GetItems().Add();
			FillPropertyValues(PrintCommandDetails, PrintCommand);
			PrintCommandDetails.Visible = Not PrintCommand.Disabled;
			If PrintCommandDetails.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors" Then
				PrintCommandDetails.Comment = String(PrintCommand.AdditionalParameters.Ref);
				PrintCommandDetails.URL = GetURL(PrintCommand.AdditionalParameters.Ref);
			EndIf;
		EndDo;
		
		RefreshCommandsOwnerCheckBox(SourceDetails);
	EndDo;
	
	CommandsTree = FormAttributeToValue("PrintCommands");
	CommandsTree.Rows.Sort("Presentation", True);
	ValueToFormAttribute(CommandsTree, "PrintCommands");
	
EndProcedure

&AtClient
Procedure Write()
	WriteCommandsSettings();
	RefreshReusableValues();
EndProcedure

&AtClient
Procedure ShowInListCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = Undefined Or QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If QuestionResult = DialogReturnCode.Yes Then
		Write();
	EndIf;
	
	GoToList();
	
EndProcedure

&AtClient
Procedure GoToList()
	
	CommandsOwner = Items.PrintCommands.CurrentData;
	If CommandsOwner = Undefined Then
		Return;
	EndIf;
	
	Parent = CommandsOwner.GetParent();
	If Parent <> Undefined Then
		CommandsOwner = Parent;
	EndIf;
	
	URL = CommandsOwner.URL;

	For Each ClientApplicationWindow In GetWindows() Do
		If ClientApplicationWindow.GetURL() = URL Then
			Form = ClientApplicationWindow.Content[0];
			NotifyDescription = New NotifyDescription("GoToListCompletion", ThisObject, 
				New Structure("Form, URL", Form, URL));
			Buttons = New ValueList;
			Buttons.Add("Reopen", NStr("ru = 'Переоткрыть'; en = 'Reopen'; pl = 'Otwórz ponownie';es_ES = 'Reabrir';es_CO = 'Reabrir';tr = 'Tekrar aç';it = 'Riaprire';de = 'Wieder öffnen'"));
			Buttons.Add("Cancel", NStr("ru = 'Не переоткрывать'; en = 'Do not reopen'; pl = 'Nie otwieraj ponownie';es_ES = 'No reabrir';es_CO = 'No reabrir';tr = 'Tekrar açma';it = 'Non riaprire';de = 'Nicht wieder öffnen'"));
			QuestionText = 
				NStr("ru = 'Список уже открыт. Переоткрыть список, 
				|чтобы увидеть изменения меню печать?'; 
				|en = 'The list is already open. Reopen the list 
				|to see the changes in Print menu?'; 
				|pl = 'Lista jest już otwarta. Otworzyć listę ponownie, 
				|żeby zobaczyć zmiany menu drukowania?';
				|es_ES = 'La lista ya está abierta. ¿Volver a abrir la lista 
				|para ver los cambios del menú impresión?';
				|es_CO = 'La lista ya está abierta. ¿Volver a abrir la lista 
				|para ver los cambios del menú impresión?';
				|tr = 'Liste zaten açık. Yazdırma menüsünün değişiklikleri görmek için listeyi tekrar aç? 
				|';
				|it = 'L''elenco è già stato aperto. Riaprire l''elenco
				|per visualizzare le modifiche nel menu di stampa?';
				|de = 'Die Liste ist bereits geöffnet. Die Liste erneut öffnen,
				|um Änderungen am Druckmenü zu sehen?'");
			ShowQueryBox(NotifyDescription, QuestionText, Buttons, , "Reopen");
			Return;
		EndIf;
	EndDo;
	
	CommonClient.OpenURL(URL);
EndProcedure

&AtClient
Procedure GoToListCompletion(QuestionResult, AdditionalParameters) Export
	If QuestionResult = "Cancel" Then
		Return;
	EndIf;
	
	AdditionalParameters.Form.Close();
	CommonClient.OpenURL(AdditionalParameters.URL);
EndProcedure

&AtClient
Procedure BeforeCloseConfirmationReceived(QuestionResult, AdditionalParameters) Export
	WriteAndClose();
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PrintCommands.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PrintCommands.Visible");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion

