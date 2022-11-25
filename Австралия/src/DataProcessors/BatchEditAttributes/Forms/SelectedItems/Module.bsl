#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SelectedTypes = Parameters.SelectedTypes;
	
	DataProcessorObject = FormAttributeToValue("Object");
	QueryText = DataProcessorObject.QueryText(SelectedTypes);
	
	InitializeSettingsComposer();
	SettingsComposer.LoadSettings(Parameters.Settings);
	
	List.QueryText = QueryText;
	
	UpdateSelectedListAtServer();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSettingsComposerSettingsFilter

&AtClient
Procedure SettingsComposerSettingsFilterOnEditEnd(Item, NewRow, CancelEdit)
	InitializeSelectedListUpdate();
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterAfterDelete(Item)
	InitializeSelectedListUpdate();
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	DetachIdleHandler("UpdateSelectedList");
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	If Item.CurrentData <> Undefined Then 
		ShowValue(, Item.CurrentData.Ref);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	Result = SettingsComposer.Settings;
	Close(Result);
EndProcedure

&AtClient
Procedure OpenItem(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	ShowValue(, CurrentData.Ref);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeSettingsComposer()
	If Not IsBlankString(Parameters.SelectedTypes) Then
		DataCompositionSchema = DataCompositionSchema(QueryText);
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	EndIf;
EndProcedure

&AtServer
Function DataCompositionSchema(QueryText)
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.DataCompositionSchema(QueryText);
EndFunction

&AtServer
Procedure UpdateSelectedListAtServer()
	
	List.SettingsComposer.LoadSettings(SettingsComposer.Settings);
	
	Structure = List.SettingsComposer.Settings.Structure;
	Structure.Clear();
	DataCompositionGroup = Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	Choice = List.SettingsComposer.Settings.Selection;
	ComboBox = Choice.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
	SelectedCount = SelectedObjects().Rows.Count();
	If SelectedCount > 1000 Then
		SelectedCount = NStr("ru = '> 1000'; en = '> 1000'; pl = '> 1000';es_ES = '> 1000';es_CO = '> 1000';tr = '> 1000';it = '> 1000';de = '> 1000'");
	ElsIf SelectedCount = 0 Then
		List.SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.Full);
	EndIf;
	Items.SelectedObjectsGroup.Title = SubstituteParametersToString(NStr("ru = 'Выбранные элементы (%1)'; en = 'Selected items (%1)'; pl = 'Wybrane elementy (%1)';es_ES = 'Elementos seleccionados (%1)';es_CO = 'Elementos seleccionados (%1)';tr = 'Seçilmiş öğeler (%1)';it = 'Elementi selezionati (%1)';de = 'Ausgewählte Elemente (%1)'"), SelectedCount);
	
EndProcedure

&AtClient
Procedure InitializeSelectedListUpdate()
	DetachIdleHandler("UpdateSelectedList");
	If Items.SelectedObjectsGroup.Visible Then
		AttachIdleHandler("UpdateSelectedList", 1, True);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateSelectedList()
	UpdateSelectedListAtServer();
EndProcedure

&AtServer
Function SelectedObjects()
	
	Result = New ValueTree;
	
	If Not IsBlankString(SelectedTypes) Then
		DataProcessorObject = FormAttributeToValue("Object");
		QueryText = DataProcessorObject.QueryText(SelectedTypes, True);
		DataCompositionSchema = DataCompositionSchema(QueryText);
		
		DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		DataCompositionSettingsComposer.LoadSettings(SettingsComposer.Settings);
		
		Result = New ValueTree;
		TemplateComposer = New DataCompositionTemplateComposer;
		Try
			DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
				DataCompositionSettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
		Except
			Return Result;
		EndTry;
		
		DataCompositionProcessor = New DataCompositionProcessor;
		DataCompositionProcessor.Initialize(DataCompositionTemplate);

		OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
		OutputProcessor.SetObject(Result);
		OutputProcessor.Output(DataCompositionProcessor);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
EndFunction

#EndRegion
