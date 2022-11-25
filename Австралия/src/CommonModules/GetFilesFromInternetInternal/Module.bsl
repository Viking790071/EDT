#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version    = "1.2.1.4";
	Handler.Procedure = "GetFilesFromInternetInternal.RefreshStoredProxySettings";
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("ProxyServerSettings", GetFilesFromInternet.ProxySettingsAtClient());
	
EndProcedure

// See SafeModeManagerOverridable.OnEnableSecurityProfiles. 
Procedure OnEnableSecurityProfiles() Export
	
	// Reset proxy settings to default condition.
	SaveServerProxySettings(Undefined);
	
	WriteLogEvent(GetFilesFromInternetClientServer.EventLogEvent(),
		EventLogLevel.Warning, Metadata.Constants.ProxyServerSetting,,
		NStr("ru = 'При включении профилей безопасности настройки прокси-сервера сброшены на системные.'; en = 'When security profile is enabled, the proxy server settings are restored to default condition.'; pl = 'Przy włączeniu profili bezpieczeństwa, ustawienia serwera pośredniczącego zostały zresetowane do ustawień domyślnych.';es_ES = 'Al activar los perfiles de seguridad, las configuraciones del servidor proxy se han restablecido para los valores por defecto.';es_CO = 'Al activar los perfiles de seguridad, las configuraciones del servidor proxy se han restablecido para los valores por defecto.';tr = 'Güvenlik profillerini etkinleştirirken, proxy sunucu ayarları varsayılan değerlere sıfırlandı.';it = 'Quando si attiva il profilo di sicurezza, vengono ripristinate le impostazioni predefinitele del server proxy.';de = 'Beim Aktivieren von Sicherheitsprofilen wurden die Proxy-Server-Einstellungen auf die Standardwerte zurückgesetzt.'"));
	
EndProcedure

#EndRegion

#Region Private

// Saves proxy server setting parameters on the 1C:Enterprise server side.
//
Procedure SaveServerProxySettings(Val Settings) Export
	
	If NOT Users.IsFullUser(, True) Then
		Raise(NStr("ru = 'Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczających uprawnień do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlem için gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	Constants.ProxyServerSetting.Set(New ValueStorage(Settings));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Initializes new proxy server settings: "UseProxy"
// and "UseSystemSettings".
//
Procedure RefreshStoredProxySettings() Export
	
	IBUsersArray = InfoBaseUsers.GetUsers();
	
	For Each InfobaseUser In IBUsersArray Do
		
		ProxyServerSetting = Common.CommonSettingsStorageLoad(
			"ProxyServerSetting", "", , , InfobaseUser.Name);
		
		If TypeOf(ProxyServerSetting) = Type("Map") Then
			
			SaveUserSettings = False;
			If ProxyServerSetting.Get("UseProxy") = Undefined Then
				ProxyServerSetting.Insert("UseProxy", False);
				SaveUserSettings = True;
			EndIf;
			If ProxyServerSetting.Get("UseSystemSettings") = Undefined Then
				ProxyServerSetting.Insert("UseSystemSettings", False);
				SaveUserSettings = True;
			EndIf;
			If SaveUserSettings Then
				Common.CommonSettingsStorageSave(
					"ProxyServerSetting", "", ProxyServerSetting, , InfobaseUser.Name);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
	
	If TypeOf(ProxyServerSetting) = Type("Map") Then
		
		SaveServerSettings = False;
		If ProxyServerSetting.Get("UseProxy") = Undefined Then
			ProxyServerSetting.Insert("UseProxy", False);
			SaveServerSettings = True;
		EndIf;
		If ProxyServerSetting.Get("UseSystemSettings") = Undefined Then
			ProxyServerSetting.Insert("UseSystemSettings", False);
			SaveServerSettings = True;
		EndIf;
		If SaveServerSettings Then
			SaveServerProxySettings(ProxyServerSetting);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
