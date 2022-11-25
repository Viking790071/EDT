#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Users.IsFullUser(Undefined, True, False) Then
		Raise NStr("en = 'Insufficient rights to administer data synchronization between applications.'; ru = 'Недостаточно прав для администрирования синхронизации данных между приложениями.';pl = 'Niewystarczające uprawnienia do administrowania synchronizacją danych między aplikacjami.';es_ES = 'Insuficientes derechos para administrar la sincronización de datos entre las aplicaciones.';es_CO = 'Insuficientes derechos para administrar la sincronización de datos entre las aplicaciones.';tr = 'Uygulamalar arasında veri senkronizasyonunu yönetmek için yetersiz haklar.';it = 'Autorizzazioni insufficienti per amministrare la sincronizzazione dei dati tra le applicazioni.';de = 'Unzureichende Rechte zum Verwalten der Datensynchronisierung zwischen Anwendungen.'");
	EndIf;
	
	RunMode = CommonCached.ApplicationRunMode();
	
	SetPrivilegedMode(True);
	
	// Settings of visible on launch
	Items.OfflineWork.Visible = False;
	Items.GroupTemporaryDirectoriesServersCluster.Visible = RunMode.ClientServer AND RunMode.ThisIsSystemAdministrator;
	
	// Update items states
	SetEnabled();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	RefreshApplicationInterface();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DataExchangeMessagesDirectoryForWindowsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForLinuxOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExchangeTransportSettings(Command)
	
	OpenForm("InformationRegister.DataExchangeTransportSettings.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure DataExchangeRules(Command)
	
	OpenForm("InformationRegister.DataExchangeRules.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure UseDataSyncOnChange(Item)
	
	If ConstantsSet.UseDataSync = False Then
		ConstantsSet.OfflineSaaS = False;
		ConstantsSet.UseDataSyncSaaSWithLocalApplication = False;
		ConstantsSet.UseDataSyncSaaSWithApplicationInInternet = False;
	EndIf;
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure OfflineSaaSOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDataSyncSaaSWithApplicationInInternetOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDataSyncSaaSWithLocalApplicationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	DriveClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

#EndRegion

#Region CallingTheServer

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ConstantName = SaveAttributeValue(AttributePathToData);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

#EndRegion

#Region Server

&AtServer
Function SaveAttributeValue(AttributePathToData)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return "";
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
		
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseDataSync" OR AttributePathToData = "" Then
		Items.DataSynchronizationSubordinatedGrouping.Enabled           = ConstantsSet.UseDataSync;
		Items.GroupDataSynchronizationMonitorSynchronizationData.Enabled = ConstantsSet.UseDataSync;
		Items.GroupTemporaryDirectoriesServersCluster.Enabled             = ConstantsSet.UseDataSync;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
