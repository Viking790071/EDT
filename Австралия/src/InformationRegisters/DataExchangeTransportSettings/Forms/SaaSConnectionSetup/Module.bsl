
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	AccountPasswordRecoveryAddress = Parameters.AccountPasswordRecoveryAddress;
	AutomaticSynchronizationSetting = Parameters.AutomaticSynchronizationSetting;
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.InternetAccessParameters.Visible = True;
	Else
		Items.InternetAccessParameters.Visible = False;
	EndIf;
	
	If Not IsBlankString(Record.WSUsername) Then
		
		User = Users.FindByName(Record.WSUsername);
		
	EndIf;
	
	For Each SynchronizationUser In DataSynchronizationUsers() Do
		
		Items.User.ChoiceList.Add(SynchronizationUser.User, SynchronizationUser.Presentation);
		
	EndDo;
	
	Items.ForgotPassword.Visible = Not IsBlankString(AccountPasswordRecoveryAddress);
	
	If ValueIsFilled(Record.Correspondent) Then
		Password = Common.ReadDataFromSecureStorage(Record.Correspondent, "WSPassword", True);
		WSPassword = ?(ValueIsFilled(Password), ThisObject.UUID, "");
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	TestServiceConnection(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If AutomaticSynchronizationSetting Then
		
		Notify("Write_ExchangeTransportSettings",
			New Structure("AutomaticSynchronizationSetting"));
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.WSRememberPassword = True;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WSPasswordOnChange(Item)
	WSPasswordChanged = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ForgotPassword(Command)
	
	DataExchangeClient.OpenInstructionHowToChangeDataSynchronizationPassword(AccountPasswordRecoveryAddress);
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParametersForm();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure TestServiceConnection(Cancel)
	
	SetPrivilegedMode(True);
	
	// Determining the user name.
	UserProperties = Users.IBUserProperies(
		Common.ObjectAttributeValue(User, "IBUserID"));
	If UserProperties <> Undefined Then
		Record.WSUsername = UserProperties.Name
	EndIf;
	
	// Testing connection to the correspondent.
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Record);
	
	If WSPasswordChanged Then
		ConnectionParameters.WSPassword = WSPassword;
	Else
		ConnectionParameters.WSPassword = Common.ReadDataFromSecureStorage(Record.Correspondent, "WSPassword", True);
	EndIf;
	
	UserMessage = "";
	If Not DataExchangeServer.CorrespondentConnectionEstablished(Record.Correspondent, ConnectionParameters, UserMessage) Then
		CommonClientServer.MessageToUser(UserMessage,, "WSPassword",, Cancel);
	Else
		// Connection check is completed successfully. Writing password if it has been changed
		If WSPasswordChanged Then
			Common.WriteDataToSecureStorage(Record.Correspondent, WSPassword, "WSPassword");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function DataSynchronizationUsers()
	
	Result = New ValueTable;
	Result.Columns.Add("User"); // Type: CatalogRef.Users
	Result.Columns.Add("Presentation");
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.Description AS Presentation,
	|	Users.IBUserID AS IBUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	NOT Users.DeletionMark
	|	AND NOT Users.Invalid
	|	AND NOT Users.Internal
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.IBUserID) Then
			
			InfobaseUser = InfoBaseUsers.FindByUUID(Selection.IBUserID);
			
			If InfobaseUser <> Undefined
				AND DataExchangeServer.DataSynchronizationPermitted(InfobaseUser) Then
				
				FillPropertyValues(Result.Add(), Selection);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
