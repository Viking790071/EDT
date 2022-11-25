#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersAndExternalUsersInfo");
	OptionSettings.Details = 
		NStr("ru = 'Выводит подробные сведения о всех пользователях,
		|включая настройки для входа (если указаны).'; 
		|en = 'Detailed information about all users,
		|including their authorization settings (if specified).'; 
		|pl = 'Wyświetla szczegółowe informacje o wszystkich użytkownikach,
		|w tym włącznie ustawienia do logowania (jeśli są podane).';
		|es_ES = 'Muestra la información detallada de todos los usuarios
		|incluyendo los ajustes para entrar (si están indicados).';
		|es_CO = 'Muestra la información detallada de todos los usuarios
		|incluyendo los ajustes para entrar (si están indicados).';
		|tr = 'Oturum açma ayarları (belirtilmişse) 
		|dahil olmak üzere tüm kullanıcılar hakkında ayrıntılı bilgi görüntüler.';
		|it = 'Visualizza informazioni dettagliate su tutti gli utenti,
		| incluse le impostazioni di accesso (se specificato).';
		|de = 'Zeigt detaillierte Informationen über alle Benutzer an,
		|einschließlich der Anmeldeeinstellungen (falls vorhanden).'");
	OptionSettings.FunctionalOptions.Add("UseExternalUsers");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersInfo");
	OptionSettings.Details = 
		NStr("ru = 'Выводит подробные сведения о пользователях,
		|включая настройки для входа (если указаны).'; 
		|en = 'Detailed information about users,
		|including their authorization settings (if specified).'; 
		|pl = 'Wyświetla szczegółowe informacje o użytkownikach,
		|w tym włącznie ustawienia do logowania (jeśli są podane).';
		|es_ES = 'Muestra la información detallada de los usuarios
		|incluyendo los ajustes para entrar (si están indicados).';
		|es_CO = 'Muestra la información detallada de los usuarios
		|incluyendo los ajustes para entrar (si están indicados).';
		|tr = 'Oturum açma ayarları (belirtilmişse) 
		|dahil olmak üzere tüm kullanıcılar hakkında ayrıntılı bilgi görüntüler.';
		|it = 'Visualizza informazioni dettagliate sugli utenti,
		| incluse le impostazioni di accesso (se specificato).';
		|de = 'Zeigt detaillierte Informationen über die Benutzer an,
		|einschließlich der Anmeldeeinstellungen (falls vorhanden).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "ExternalUsersInfo");
	OptionSettings.Details = 
		NStr("ru = 'Выводит подробные сведения о внешних пользователях,
		|включая настройки для входа (если указаны).'; 
		|en = 'Detailed information about external users,
		|including their authorization settings (if specified).'; 
		|pl = 'Wyświetla szczegółowe informacje o zewnętrznych użytkownikach,
		|w tym włącznie ustawienia do logowania (jeśli są podane).';
		|es_ES = 'Visualiza la información detallada sobre los usuarios externos,
		|incluyendo los ajustes del inicio de sesión (si están especificados).';
		|es_CO = 'Visualiza la información detallada sobre los usuarios externos,
		|incluyendo los ajustes del inicio de sesión (si están especificados).';
		|tr = 'Oturum açma ayarları (belirtilmişse) 
		|dahil olmak üzere tüm kullanıcılar hakkında ayrıntılı bilgi görüntüler.';
		|it = 'Visualizza informazioni dettagliate sugli utenti esterni,
		| incluse le impostazioni di accesso (se specificato).';
		|de = 'Zeigt detaillierte Informationen über externe Benutzer an,
		|einschließlich der Anmeldeeinstellungen (falls vorhanden).'");
	OptionSettings.FunctionalOptions.Add("UseExternalUsers");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	If Not Parameters.Property("VariantKey") Then
		StandardProcessing = False;
		Parameters.Insert("VariantKey", "UsersAndExternalUsersInfo");
		SelectedForm = "Report.UsersInfo.Form";
	EndIf;
	
EndProcedure

#EndRegion
