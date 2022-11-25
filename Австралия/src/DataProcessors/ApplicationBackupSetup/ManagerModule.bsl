#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	StandardProcessing = False;
	
	SetPrivilegedMode(True);
	
	Versions = GetWebServiceVersions();
	
	If Versions.Find("1.0.2.1") <> Undefined Then
	
		SelectedForm = "SetWithIntervals";
			
		DataArea = SaaS.SessionSeparatorValue();
		
		AdditionalParameters = DataAreaBackupFormDataInterface.
			GetSettingsFormParameters(DataArea);
		For each KeyAndValue In AdditionalParameters Do
			Parameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		
	ElsIf DataAreasBackupCached.ServiceManagerSupportsBackup() Then
		
		SelectedForm = "SetWithoutIntervals";
		
	Else
#EndIf
		
		Raise(NStr("ru = 'Менеджер сервиса не поддерживает резервное копирование приложений'; en = 'The service manager does not support application backup'; pl = 'Menedżer usług nie obsługuje tworzenia kopii zapasowych aplikacji';es_ES = 'Gestor de servicio no admite la copia de respaldo de la aplicación';es_CO = 'Gestor de servicio no admite la copia de respaldo de la aplicación';tr = 'Servis yöneticisi uygulama yedeğini desteklemiyor';it = 'Il manager di servizio non supporta il backup dell''applicazione';de = 'Service Manager unterstützt keine Anwendungssicherung'"));
		
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	EndIf;
#EndIf
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
Function GetWebServiceVersions()
	
	Return Common.GetInterfaceVersions(
		SaaS.InternalServiceManagerURL(),
		SaaS.AuxiliaryServiceManagerUsername(),
		SaaS.AuxiliaryServiceManagerUserPassword(),
		"ZoneBackupControl");

EndFunction
#EndIf

#EndRegion
