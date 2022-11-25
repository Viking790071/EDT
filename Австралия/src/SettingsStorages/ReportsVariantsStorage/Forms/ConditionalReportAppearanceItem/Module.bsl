#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("SettingsComposer", SettingsComposer) Then
		Raise NStr("ru = 'The ""SettingsComposer"" service parameter is not passed.'; en = 'The ""SettingsComposer"" service parameter is not passed.'; pl = 'The ""SettingsComposer"" service parameter is not passed.';es_ES = 'The ""SettingsComposer"" service parameter is not passed.';es_CO = 'The ""SettingsComposer"" service parameter is not passed.';tr = 'The ""SettingsComposer"" service parameter is not passed.';it = 'The ""SettingsComposer"" service parameter is not passed.';de = 'The ""SettingsComposer"" service parameter is not passed.'");
	EndIf;
	If Not Parameters.Property("ReportSettings", ReportSettings) Then
		Raise NStr("ru = 'The ""ReportSettings"" service parameter is not passed.'; en = 'The ""ReportSettings"" service parameter is not passed.'; pl = 'The ""ReportSettings"" service parameter is not passed.';es_ES = 'The ""ReportSettings"" service parameter is not passed.';es_CO = 'The ""ReportSettings"" service parameter is not passed.';tr = 'The ""ReportSettings"" service parameter is not passed.';it = 'The ""ReportSettings"" service parameter is not passed.';de = 'The ""ReportSettings"" service parameter is not passed.'");
	EndIf;
	If Not Parameters.Property("CurrentDCNodeID", CurrentDCNodeID) Then
		Raise NStr("ru = 'Service parameter CurrentDCNodeID is not passed.'; en = 'Service parameter CurrentDCNodeID is not passed.'; pl = 'Service parameter CurrentDCNodeID is not passed.';es_ES = 'Service parameter CurrentDCNodeID is not passed.';es_CO = 'Service parameter CurrentDCNodeID is not passed.';tr = 'Service parameter CurrentDCNodeID is not passed.';it = 'Service parameter CurrentDCNodeID is not passed.';de = 'Service parameter CurrentDCNodeID is not passed.'");
	EndIf;
	If Not Parameters.Property("DCID", DCID) Then
		Raise NStr("ru = 'Service parameter DCID is not passed.'; en = 'Service parameter DCID is not passed.'; pl = 'Service parameter DCID is not passed.';es_ES = 'Service parameter DCID is not passed.';es_CO = 'Service parameter DCID is not passed.';tr = 'Service parameter DCID is not passed.';it = 'Service parameter DCID is not passed.';de = 'Service parameter DCID is not passed.'");
	EndIf;
	If Not Parameters.Property("Description", Description) Then
		Raise NStr("ru = 'Service parameter ""Name"" is not transferred.'; en = 'Service parameter ""Name"" is not transferred.'; pl = 'Service parameter ""Name"" is not transferred.';es_ES = 'Service parameter ""Name"" is not transferred.';es_CO = 'Service parameter ""Name"" is not transferred.';tr = 'Service parameter ""Name"" is not transferred.';it = 'Service parameter ""Name"" is not transferred.';de = 'Service parameter ""Name"" is not transferred.'");
	EndIf;
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	DCNode = SettingsComposer.Settings.ConditionalAppearance;
	If DCID = Undefined Then // New item
		IsNew = True;
		DCItem = DCNode.Items.Insert(0);
		DCItem.Use = True;
		DCItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
		Items.Description.ClearButton = False;
	Else
		DCNodeSource = DCNode(ThisObject);
		If DCNodeSource = Undefined Then
			Raise NStr("ru = 'Report node is not found.'; en = 'Report node is not found.'; pl = 'Report node is not found.';es_ES = 'Report node is not found.';es_CO = 'Report node is not found.';tr = 'Report node is not found.';it = 'Report node is not found.';de = 'Report node is not found.'");
		EndIf;
		DCItemSource = DCNodeSource.GetObjectByID(DCID);
		If DCItemSource = Undefined Then
			Raise NStr("ru = 'Item of conditional appearance is not found.'; en = 'Item of conditional appearance is not found.'; pl = 'Item of conditional appearance is not found.';es_ES = 'Item of conditional appearance is not found.';es_CO = 'Item of conditional appearance is not found.';tr = 'Item of conditional appearance is not found.';it = 'Item of conditional appearance is not found.';de = 'Item of conditional appearance is not found.'");
		EndIf;
		DCItem = ReportsClientServer.CopyRecursive(DCNode, DCItemSource, DCNode.Items, 0, New Map);
		
		DefaultDescription = ReportsClientServer.ConditionalAppearanceItemPresentation(DCItem, Undefined, "");
		DescriptionOverridden = (Description <> "" AND Description <> DefaultDescription);
		Items.Description.InputHint = DefaultDescription;
		If Not DescriptionOverridden Then
			Description = "";
			Items.Description.ClearButton = False;
		EndIf;
	EndIf;
	
	For Each CheckBoxField In Items.GroupDisplayArea.ChildItems Do
		CheckBoxName = CheckBoxField.Name;
		DisplayAreaCheckBoxes.Add(CheckBoxName);
		If DCItem[CheckBoxName] = DataCompositionConditionalAppearanceUse.Use Then
			ThisObject[CheckBoxName] = True;
		EndIf;
	EndDo;
	
	CloseOnChoice = False;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	If Description = "" Or Description = Items.Description.InputHint Then
		DefaultDescriptionUpdateRequired = True;
		UpdateDefaultDescriptionIfRequired();
		Items.Description.ClearButton = False;
	Else
		Items.Description.ClearButton = True;
	EndIf;
EndProcedure

&AtClient
Procedure UseInGroupOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure UseInHierarchicalGroupOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure UseInOverallOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure UseInFieldsTitleOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure UseInTitleOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure UseInParametersOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure UseInFilterOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAppearance

&AtClient
Procedure AppearanceOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilter

&AtClient
Procedure FilterOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFormattedFields

&AtClient
Procedure FormattedFieldsOnChange(Item)
	UpdateDefaultDescription();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	SelectAndClose();
EndProcedure

&AtClient
Procedure Show_SelectCheckBoxes(Command)
	For Each ListItem In DisplayAreaCheckBoxes Do
		ThisObject[ListItem.Value] = True;
	EndDo;
	UpdateDefaultDescription();
EndProcedure

&AtClient
Procedure Show_ClearCheckBoxes(Command)
	For Each ListItem In DisplayAreaCheckBoxes Do
		ThisObject[ListItem.Value] = False;
	EndDo;
EndProcedure

&AtClient
Procedure InsertDefaultDescription(Command)
	Description = DefaultDescription;
	Items.Description.ClearButton = False;
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Function DCNode(Form)
	If Form.CurrentDCNodeID = Undefined Then
		Return Form.SettingsComposer.Settings.ConditionalAppearance;
	Else
		DCCurrentNode = Form.SettingsComposer.Settings.GetObjectByID(Form.CurrentDCNodeID);
		Return DCCurrentNode.ConditionalAppearance;
	EndIf;
EndFunction

&AtClient
Procedure UpdateDefaultDescription()
	DefaultDescriptionUpdateRequired = True;
	If Description = "" Or Description = Items.Description.InputHint Then
		AttachIdleHandler("UpdateDefaultDescriptionIfRequired", 1, True);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateDefaultDescriptionIfRequired()
	If Not DefaultDescriptionUpdateRequired Then
		Return;
	EndIf;
	DefaultDescriptionUpdateRequired = False;
	DCNode = SettingsComposer.Settings.ConditionalAppearance;
	DCItem = DCNode.Items[0];
	DefaultDescription = ReportsClientServer.ConditionalAppearanceItemPresentation(DCItem, Undefined, "");
	If Description = Items.Description.InputHint Then
		Description = DefaultDescription;
		Items.Description.InputHint = DefaultDescription;
	ElsIf Description = "" Then
		Items.Description.InputHint = DefaultDescription;
	EndIf;
EndProcedure

&AtClient
Procedure SelectAndClose()
	DetachIdleHandler("UpdateDefaultDescriptionIfRequired");
	UpdateDefaultDescriptionIfRequired();
	
	If Description = "" Then
		Description = DefaultDescription;
	EndIf;
	
	DCItem = SettingsComposer.Settings.ConditionalAppearance.Items[0];
	
	If Description = DefaultDescription Then
		DCItem.UserSettingPresentation = "";
	Else
		DCItem.UserSettingPresentation = Description;
	EndIf;
	
	For Each ListItem In DisplayAreaCheckBoxes Do
		CheckBoxName = ListItem.Value;
		If ThisObject[CheckBoxName] Then
			DCItem[CheckBoxName] = DataCompositionConditionalAppearanceUse.Use;
		Else
			DCItem[CheckBoxName] = DataCompositionConditionalAppearanceUse.DontUse;
		EndIf;
	EndDo;
	
	Result = New Structure("DCItem, Description", DCItem, Description);
	NotifyChoice(Result);
	Close(Result);
EndProcedure

#EndRegion