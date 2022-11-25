///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	InitializeFilters();
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		SendSMSMessageEnabled = True;
		EmailOperationsEnabled = True;
	Else
		EmailOperationsEnabled = Common.SubsystemExists("StandardSubsystems.EmailOperations");
		SendSMSMessageEnabled = Common.SubsystemExists("StandardSubsystems.SMS");
	EndIf;
	
	// buttons are in the group; if there is one button, the group is not required
	Items.FormCreateSMSMessageTemplate.Visible = SendSMSMessageEnabled;
	Items.FormCreateEmailTemplate.Visible = EmailOperationsEnabled;
	
	Items.FormShowContextTemplates.Visible = Users.IsFullUser();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_MessagesTemplates" Then
		InitializeFilters();
		SetAssignmentFilter(Purpose);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AssignmentFilterOnChange(Item)
	SetAssignmentFilter(Purpose);
EndProcedure

&AtClient
Procedure TemplateForFilterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ValueSelected = "SMS" Then
		CommonClientServer.SetFilterItem(List.Filter, "TemplateFor", NStr("ru = 'Сообщение SMS'; en = 'Text message'; pl = 'Wiadomość SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS';it = 'Messaggio di testo';de = 'Textnachricht'"), DataCompositionComparisonType.Equal);
	ElsIf ValueSelected = "Email" Then
		CommonClientServer.SetFilterItem(List.Filter, "TemplateFor", NStr("ru = 'Электронное письмо'; en = 'Email message'; pl = 'Wiadomość e-mail';es_ES = 'Mensaje de correo electrónico';es_CO = 'Mensaje de correo electrónico';tr = 'E-posta iletisi';it = 'Messaggio email';de = 'E-Mail-Nachricht'"), DataCompositionComparisonType.Equal);
	Else
		CommonClientServer.DeleteFilterItems(List.Filter, "TemplateFor");
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtServerNoContext
Procedure ListOnReceiveDataAtServer(ItemName, Settings, Rows)
	
	Query = New Query("SELECT 
	| MessagesTemplatesPrintFormsAndAttachments.Ref AS Ref
	|FROM
	|	Catalog.MessageTemplates.PrintFormsAndAttachments AS MessagesTemplatesPrintFormsAndAttachments
	|WHERE
	| MessagesTemplatesPrintFormsAndAttachments.Ref IN (&MessageTemplates)
	|GROUP BY
	| MessagesTemplatesPrintFormsAndAttachments.Ref");
	Query.SetParameter("MessageTemplates", Rows.GetKeys());
	Result = Query.Execute().Unload().UnloadColumn("Ref");
	For each MessagesTemplate In Result Do
		ListLine = Rows[MessagesTemplate];
		ListLine.Data["HasFiles"] = 1;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateEmailTemplate(Command)
	CreateTemplate("EmailMessage");
EndProcedure

&AtClient
Procedure CreateSMSMessageTemplate(Command)
	CreateTemplate("SMSMessage");
EndProcedure

&AtClient
Procedure ShowContextTemplates(Command)
	Items.FormShowContextTemplates.Check = Not Items.FormShowContextTemplates.Check;
	List.Parameters.SetParameterValue("ShowContextTemplates", Items.FormShowContextTemplates.Check);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CreateTemplate(MessageType)
	FormParameters = New Structure();
	FormParameters.Insert("MessageKind",           MessageType);
	FormParameters.Insert("FullBasisTypeName", Purpose);
	FormParameters.Insert("CanChangeAssignment",  True);
	OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure SetAssignmentFilter(Val SelectedValue)
	
	If IsBlankString(SelectedValue) Then
		CommonClientServer.DeleteFilterItems(List.Filter, "Purpose");
	Else
		CommonClientServer.SetFilterItem(List.Filter, "Purpose", SelectedValue, DataCompositionComparisonType.Equal);
	EndIf;

EndProcedure

&AtServer
Procedure InitializeFilters()
	
	Items.AssignmentFilter.ChoiceList.Clear();
	Items.TemplateForFilter.ChoiceList.Clear();
	
	List.Parameters.SetParameterValue("Purpose", "");
	
	TemplatesKinds = MessageTemplatesInternal.TemplatesKinds();
	TemplatesKinds.Insert(0, NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle/s'"), NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle/s'"));
	
	List.Parameters.SetParameterValue("SMSMessage", TemplatesKinds.FindByValue("SMS").Presentation);
	List.Parameters.SetParameterValue("Email", TemplatesKinds.FindByValue("Email").Presentation);
	List.Parameters.SetParameterValue("ShowContextTemplates", False);
	
	For each TemplateKind In TemplatesKinds Do
		Items.TemplateForFilter.ChoiceList.Add(TemplateKind.Value, TemplateKind.Presentation);
	EndDo;
	
	Items.AssignmentFilter.ChoiceList.Add("", NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle/s'"));
	
	List.Parameters.SetParameterValue(MessageTemplatesClientServer.CommonID(),
		MessageTemplatesClientServer.CommonID());
	Items.AssignmentFilter.ChoiceList.Add(MessageTemplatesClientServer.CommonID(), 
		MessageTemplatesClientServer.CommonIDPresentation());
		
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	MessageTemplates.Purpose AS Purpose,
		|	MessageTemplates.InputOnBasisParameterTypeFullName AS InputOnBasisParameterTypeFullName
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.Purpose <> """" AND MessageTemplates.Purpose <> ""Internal""
		|	AND MessageTemplates.Purpose <> &Common
		|
		|GROUP BY
		|	MessageTemplates.Purpose, MessageTemplates.InputOnBasisParameterTypeFullName
		|
		|ORDER BY
		|	Purpose";
	
	Query.SetParameter("Common", MessageTemplatesClientServer.CommonID());
	QueryResult = Query.Execute().Select();
	
	OnDefineSettings =  MessagesTemplatesInternalCachedModules.OnDefineSettings();
	TemplatesSubjects = OnDefineSettings.TemplateSubjects;
	While QueryResult.Next() Do
		FoundRow = TemplatesSubjects.Find(QueryResult.InputOnBasisParameterTypeFullName, "Name");
		Presentation = ?( FoundRow <> Undefined, FoundRow.Presentation, QueryResult.Purpose);
		
		Items.AssignmentFilter.ChoiceList.Add(QueryResult.InputOnBasisParameterTypeFullName, Presentation);
	EndDo;
	
	Purpose = "";
	TemplateFor = NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle/s'");
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Ref.TemplateOwner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Purpose.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Purpose");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = MessageTemplatesClientServer.CommonID();
	
	Item.Appearance.SetParameterValue("Text", MessageTemplatesClientServer.CommonIDPresentation());
	
	//
	OnDefineSettings =  MessagesTemplatesInternalCachedModules.OnDefineSettings();
	TemplatesSubjects = OnDefineSettings.TemplateSubjects;
	
	For each TemplateSubject In TemplatesSubjects Do
	
		Item = List.ConditionalAppearance.Items.Add();
		
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(Items.Purpose.Name);
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("Purpose");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = TemplateSubject.Name;
		
		Item.Appearance.SetParameterValue("Text", TemplateSubject.Presentation);
	
	EndDo;
	
EndProcedure

#EndRegion
