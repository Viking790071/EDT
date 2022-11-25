
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Date                        = Parameters.Date;
	UserName             = Parameters.UserName;
	ApplicationPresentation     = Parameters.ApplicationPresentation;
	Computer                   = Parameters.Computer;
	Event                     = Parameters.Event;
	EventPresentation        = Parameters.EventPresentation;
	Comment                 = Parameters.Comment;
	MetadataPresentation     = Parameters.MetadataPresentation;
	Data                      = Parameters.Data;
	DataPresentation         = Parameters.DataPresentation;
	TransactionID                  = Parameters.TransactionID;
	TransactionStatus            = Parameters.TransactionStatus;
	Session                       = Parameters.Session;
	ServerName               = Parameters.ServerName;
	Port              = Parameters.Port;
	SyncPort       = Parameters.SyncPort;
	
	If Parameters.Property("SessionDataSeparation") Then
		SessionDataSeparation = Parameters.SessionDataSeparation;
	EndIf;
	
	// Enabling the open button for the metadata list.
	If TypeOf(MetadataPresentation) = Type("ValueList") Then
		Items.MetadataPresentation.OpenButton = True;
		Items.AccessMetadataPresentation.OpenButton = True;
		Items.AccessRightDeniedMetadataPresentation.OpenButton = True;
		Items.AccessActionDeniedMetadataPresentation.OpenButton = True;
	EndIf;
	
	// Processing special event data.
	Items.AccessData.Visible = False;
	Items.AccessRightDeniedData.Visible = False;
	Items.AccessActionDeniedData.Visible = False;
	Items.AuthenticationData.Visible = False;
	Items.IBUserData.Visible = False;
	Items.SimpleData.Visible = False;
	Items.DataPresentations.PagesRepresentation = FormPagesRepresentation.None;
	
	If Event = "_$Access$_.Access" Then
		Items.DataPresentations.CurrentPage = Items.AccessData;
		Items.AccessData.Visible = True;
		EventData = GetFromTempStorage(Parameters.DataAddress);
		If EventData <> Undefined Then
			CreateFormTable("AccessDataTable", "DataTable", EventData.Data);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	ElsIf Event = "_$Access$_.AccessDenied" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		
		If EventData <> Undefined Then
			If EventData.Property("Right") Then
				Items.DataPresentations.CurrentPage = Items.AccessRightDeniedData;
				Items.AccessRightDeniedData.Visible = True;
				AccessRightDenied = EventData.Right;
			Else
				Items.DataPresentations.CurrentPage = Items.AccessActionDeniedData;
				Items.AccessActionDeniedData.Visible = True;
				AccessActionDenied = EventData.Action;
				CreateFormTable("AccessActionDeniedDataTable", "DataTable", EventData.Data);
				Items.Comment.VerticalStretch = False;
				Items.Comment.Height = 1;
			EndIf;
		EndIf;
		
	ElsIf Event = "_$Session$_.Authentication"
		  OR Event = "_$Session$_.AuthenticationError" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		Items.DataPresentations.CurrentPage = Items.AuthenticationData;
		Items.AuthenticationData.Visible = True;
		If EventData <> Undefined Then
			EventData.Property("Name",                   AuthenticationUsername);
			EventData.Property("OSUser",        AuthenticationOSUser);
			EventData.Property("CurrentOSUser", AuthenticationCurrentOSUser);
		EndIf;
		
	ElsIf Event = "_$User$_.Delete"
		  OR Event = "_$User$_.New"
		  OR Event = "_$User$_.Update" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		Items.DataPresentations.CurrentPage = Items.IBUserData;
		Items.IBUserData.Visible = True;
		IBUserProperies = New ValueTable;
		IBUserProperies.Columns.Add("Name");
		IBUserProperies.Columns.Add("Value");
		RolesArray = Undefined;
		If EventData <> Undefined Then
			For each KeyAndValue In EventData Do
				If KeyAndValue.Key = "Roles" Then
					RolesArray = KeyAndValue.Value;
					Continue;
				EndIf;
				NewRow = IBUserProperies.Add();
				NewRow.Name      = KeyAndValue.Key;
				NewRow.Value = KeyAndValue.Value;
			EndDo;
		EndIf;
		CreateFormTable("IBUserPropertiesTable", "DataTable", IBUserProperies);
		If RolesArray <> Undefined Then
			IBUserRoles = New ValueTable;
			IBUserRoles.Columns.Add("Role",, NStr("ru = 'Роль'; en = 'Role'; pl = 'Rola';es_ES = 'Rol';es_CO = 'Rol';tr = 'Rol';it = 'Ruolo';de = 'Rolle'"));
			For each CurrentRole In RolesArray Do
				IBUserRoles.Add().Role = CurrentRole;
			EndDo;
			CreateFormTable("IBUserRolesTable", "Roles", IBUserRoles);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	Else
		Items.DataPresentations.CurrentPage = Items.SimpleData;
		Items.SimpleData.Visible = True;
	EndIf;
	
	Items.SessionDataSeparation.Visible = Not Common.SeparatedDataUsageAvailable();
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject, "DataGroup, EventGroup, ConnectionGroup, TransactionIDGroup");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MetadataPresentationOpening(Item, StandardProcessing)
	
	ShowValue(, MetadataPresentation);
	
EndProcedure

&AtClient
Procedure SessionDataSeparationOpening(Item, StandardProcessing)
	
	ShowValue(, SessionDataSeparation);
	
EndProcedure

#EndRegion

#Region AccessActionDeniedDataTableFormTableItemsEventHandlers

&AtClient
Procedure DataTableChoice(Item, RowSelected, Field, StandardProcessing)
	
	ShowValue(, Item.CurrentData[Mid(Field.Name, StrLen(Item.Name)+1)]);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CreateFormTable(Val FormTableFieldName, Val AttributeNameFormDataCollection, Val ValueTable)
	
	If TypeOf(ValueTable) <> Type("ValueTable") Then
		ValueTable = New ValueTable;
		ValueTable.Columns.Add("Undefined", , " ");
	EndIf;
	
	// Adding form table attributes.
	AttributesToAdd = New Array;
	For each Column In ValueTable.Columns Do
		AttributesToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, AttributeNameFormDataCollection, Column.Title));
	EndDo;
	ChangeAttributes(AttributesToAdd);
	
	// Adding items to form
	For each Column In ValueTable.Columns Do
		AttributeItem = Items.Add(FormTableFieldName + Column.Name, Type("FormField"), Items[FormTableFieldName]);
		AttributeItem.DataPath = AttributeNameFormDataCollection + "." + Column.Name;
	EndDo;
	
	ValueToFormAttribute(ValueTable, AttributeNameFormDataCollection);
	
EndProcedure

#EndRegion
