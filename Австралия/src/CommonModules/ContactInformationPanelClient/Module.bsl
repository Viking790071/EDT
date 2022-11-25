
#Region FormItemEvents

Procedure ContactInformationPanelDataSelection(Form, Item, SelectedRow, Field, StandardProcessing) Export
	
	StandardProcessing = False;
	
	RowCI = Form.ContactInformationPanelData.FindByID(SelectedRow);
	
	If RowCI.TypeShowingData = "ValueCI" Then
		
		If RowCI.IconIndex = 20 Then // Skype
			Parameters = New Structure("SkypeUsername");
			Parameters.SkypeUsername = RowCI.PresentationCI;
			List = New ValueList;
			List.Add("Call", NStr("en = 'Call'; ru = 'Позвонить';pl = 'Zadzwoń';es_ES = 'Llamada';es_CO = 'Llamada';tr = 'Ara';it = 'Chiamata';de = 'Anruf'"));
			List.Add("StartChat", NStr("en = 'Start chat'; ru = 'Начать чат';pl = 'Rozpocznij czat';es_ES = 'Empezar la conversación';es_CO = 'Empezar la conversación';tr = 'Sohbeti başlat';it = 'Iniziare chat';de = 'Chat beginnen'"));
			NotifyDescription = New NotifyDescription("AfterChoiceFromSkypeMenu", ContactsManagerClient, Parameters);
			Form.ShowChooseFromMenu(NotifyDescription, List);
			Return;
		EndIf;
		
		If Form.UseDocumentEvent Then	
			
			FillBasis = New Structure("Contact", RowCI.OwnerCI);
			
			FillingValues = New Structure("EventType,FillBasis", 
				EventTypeByContactInformationType(RowCI.IconIndex),
				FillBasis);
				
			FormParameters = New Structure("FillingValues", FillingValues);
			OpenForm("Document.Event.ObjectForm", FormParameters, Form);
		
		EndIf;
		
	ElsIf RowCI.TypeShowingData = "ContactPerson" Then
		
		ShowValue(,RowCI.OwnerCI);
		
	EndIf;
	
EndProcedure

Procedure ContactInformationPanelDataOnActivateRow(Form, Item) Export
	
	RowCI = Form.Items.ContactInformationPanelData.CurrentData;
	If RowCI = Undefined Then
		Return;
	EndIf;
	
	ButtonGoogle = Form.Items.Find("ContextMenuPanelMapGoogle");
	If ButtonGoogle <> Undefined Then
		ButtonGoogle.Enabled = RowCI.TypeShowingData = "ValueCI"
			AND RowCI.IconIndex = 12; // address
	EndIf;
	
EndProcedure

Procedure ExecuteCommand(Form, Command) Export
	
	RowCI = Form.Items.ContactInformationPanelData.CurrentData;
	If RowCI = Undefined Then
		Return;
	EndIf;
	
	If Command.Name = "ContextMenuPanelMapGoogle" Then
		ContactsManagerClient.ShowAddressOnMap(RowCI.PresentationCI, "GoogleMaps");
	EndIf;
	
EndProcedure

#EndRegion

#Region Interface

Function ProcessNotifications(Form, EventName, Parameter) Export
	
	Result = EventName = "Write_Counterparty"
			Or EventName = "Write_ContactPerson";
		
	Return Result;
	
EndFunction
	
#EndRegion

#Region ServiceProceduresAndFunctions

Function EventTypeByContactInformationType(IconIndex)
	
	If IconIndex = 12 Then
		EventType = PredefinedValue("Enum.EventTypes.PersonalMeeting");
	ElsIf IconIndex = 8 Then
		EventType = PredefinedValue("Enum.EventTypes.Email");
	ElsIf IconIndex = 9 Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf IconIndex = 20 Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf IconIndex = 11 Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf IconIndex = 7 Then
		EventType = PredefinedValue("Enum.EventTypes.PhoneCall");
	ElsIf IconIndex = 10 Then
		EventType = PredefinedValue("Enum.EventTypes.PhoneCall");
	Else
		EventType = PredefinedValue("Enum.EventTypes.EmptyRef");
	EndIf;
	
	Return EventType;
	
EndFunction

#EndRegion
