
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseEDIExchangeOnChange(Item)
	
	Attachable_OnAttributeChange(Item, True, Not ConstantsSet.UseEDIExchange);
	
EndProcedure

&AtClient
Procedure UseExchangeWithWebsiteOnChange(Item)
	
	Attachable_OnAttributeChange(Item, True, Not ConstantsSet.UseExchangeWithWebsite);
	
EndProcedure

&AtClient
Procedure ProhibitEDocumentsChangingOnChange(Item)
	
	Attachable_OnAttributeChange(Item, True);
	
EndProcedure

&AtClient
Procedure UseExchangeWithProManageOnChange(Item)
	
	Attachable_OnAttributeChange(Item, True, Not ConstantsSet.UseDataExchangeWithProManage);
	
EndProcedure

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonCached.ApplicationRunMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
	// begin Drive.FullVersion
	OpenProManageSettingsCommand = Commands.Add("ProManageSettings");
	OpenProManageSettingsCommand.Action = "ProManageSettings";
	OpenProManageSettingsCommand.Title = NStr("en = 'Exchange settings'; ru = 'Exchange settings';pl = 'Exchange settings';es_ES = 'Exchange settings';es_CO = 'Exchange settings';tr = 'Exchange settings';it = 'Exchange settings';de = 'Exchange settings'");
	
	ProManageSettings = Items.Add("ProManageSettings",
	                                 Type("FormButton"),
									 Items.Group3);
	ProManageSettings.CommandName = "ProManageSettings";
	ProManageSettings.Type = FormButtonType.Hyperlink;
	// end Drive.FullVersion
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CatalogEDIProfiles(Command)
	
	OpenForm("Catalog.EDIProfiles.ListForm");
	
EndProcedure

&AtClient
Procedure CatalogEDocumentStatuses(Command)
	
	OpenForm("Catalog.EDocumentStatuses.ListForm");
	
EndProcedure

&AtClient
Procedure CatalogIntegrationComponents(Command)
	OpenForm("Catalog.IntegrationComponents.ListForm");
EndProcedure

&AtClient
Procedure CatalogExchangeSettings(Command)
	
	OpenForm("ExchangePlan.Website.ListForm");
	
EndProcedure

&AtClient
Procedure Salespersons(Command)

	FormParameters = New Structure("PerformerRole", PredefinedValue("Catalog.PerformerRoles.Salespersons"));
	OpenForm("InformationRegister.TaskPerformers.Form.RolePerformers", FormParameters, 
		ThisObject, True);
	
EndProcedure

// begin Drive.FullVersion
&AtClient
Procedure ProManageSettings(Command)

	OpenForm("ExchangePlan.Promanage.ListForm");
	
EndProcedure
// end Drive.FullVersion

#EndRegion

#Region Private

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True, ShowQueryBox = False)
	
	If ShowQueryBox Then
		
		QueryParameters = New Structure;
		QueryParameters.Insert("Item", Item);
		QueryParameters.Insert("RefreshingInterface", RefreshingInterface);
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("OnAttributeChangeQueryClose", ThisObject, QueryParameters);
		ShowQueryBox(Notification, NStr("en = 'Do you want to disable the exchange?'; ru = 'Отключить обмен?';pl = 'Czy chcesz wyłączyć wymianę?';es_ES = '¿Quiere desactivar el intercambio?';es_CO = '¿Quiere desactivar el intercambio?';tr = 'Değişimi devre dışı bırakmak istiyor musunuz?';it = 'Disabilitare lo scambio?';de = 'Möchten Sie den Austausch deaktivieren?'"), Mode, 0);
		
	Else
		
		OnAttributeChangeClient(Item, RefreshingInterface);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnAttributeChangeQueryClose(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		OnAttributeChangeClient(Parameters.Item, Parameters.RefreshingInterface);
		
	Else
		
		ReturnFormAttributeValue(Parameters.Item.Name);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ReturnFormAttributeValue(ItemName)
	
	AttributePathToData = Items[ItemName].DataPath;
	
	If AttributePathToData = "ConstantsSet.UseEDIExchange" Then
		ConstantsSet.UseEDIExchange = Constants.UseEDIExchange.Get();
	ElsIf AttributePathToData = "ConstantsSet.UseExchangeWithWebsite" Then
		ConstantsSet.UseExchangeWithWebsite = Constants.UseExchangeWithWebsite.Get();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnAttributeChangeClient(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If NOT WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If NOT WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.IsSystemAdministrator Then
		
		If AttributePathToData = "ConstantsSet.UseEDIExchange" OR AttributePathToData = "" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"GroupCatalogs",
				"Enabled",
				ConstantsSet.UseEDIExchange);
			
			CommonClientServer.SetFormItemProperty(Items,
				"ProhibitEDocumentsChanging",
				"Enabled",
				ConstantsSet.UseEDIExchange);
			
			EndIf;
			
		If AttributePathToData = "ConstantsSet.UseExchangeWithWebsite" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "GroupWebsiteCatalogs", "Enabled", ConstantsSet.UseExchangeWithWebsite);
		EndIf;
		
		// begin Drive.FullVersion
		If AttributePathToData = "ConstantsSet.UseDataExchangeWithProManage" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "ProManageSettings", "Enabled", ConstantsSet.UseDataExchangeWithProManage);
		EndIf;
		// end Drive.FullVersion
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	If AttributePathToData = "ConstantsSet.UseExchangeWithWebsite" Then
		
		If Constants.UseExchangeWithWebsite.Get() <> ConstantsSet.UseExchangeWithWebsite Then
			
			If Constants.UseBusinessProcessesAndTasks.Get() <> ConstantsSet.UseExchangeWithWebsite
				And ConstantsSet.UseExchangeWithWebsite Then
				Constants.UseBusinessProcessesAndTasks.Set(True);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SaveAttributeValue(AttributePathToData, Result);

	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseExchangeWithWebsite" Then
		
		If ConstantsSet.UseExchangeWithWebsite Then
			SetDescriptionAndCodeForThisNode("Website");
		EndIf;
		
	ElsIf AttributePathToData = "ConstantsSet.UseDataExchangeWithProManage" Then

		If ConstantsSet.UseDataExchangeWithProManage Then
			SetDescriptionAndCodeForThisNode("ProManage");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDescriptionAndCodeForThisNode(NodeName)

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	NodeTable.Ref AS Ref
	|FROM
	|	&TableName AS NodeTable
	|WHERE
	|	NodeTable.Code = """"
	|	AND NodeTable.Description = """"
	|	AND NodeTable.ThisNode";
	
	Query.Text = StrReplace(Query.Text, "&TableName", "ExchangePlan." + NodeName);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		ExchangeNodeObject = Selection.Ref.GetObject();
		ExchangeNodeObject.Code = "001";
		ExchangeNodeObject.Description = NStr("en = 'Drive'; ru = 'Drive';pl = 'Drive';es_ES = 'Drive';es_CO = 'Drive';tr = 'Drive';it = 'Drive';de = 'Drive'");
		ExchangeNodeObject.Write();
		
	EndIf;

EndProcedure

#EndRegion
