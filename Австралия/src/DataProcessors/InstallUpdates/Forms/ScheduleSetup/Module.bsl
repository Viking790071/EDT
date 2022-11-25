
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ConfigurationUpdateOptions = DataProcessors.InstallUpdates.GetSettingsStructureOfAssistant();
	FillPropertyValues(Object, ConfigurationUpdateOptions);
	Object.ScheduleOfUpdateExistsCheck = CommonClientServer.StructureToSchedule(Object.ScheduleOfUpdateExistsCheck);
	
	SetScheduleVisible(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CheckUpdateExistsOnStartOnChange(Item)
	
	SetScheduleVisible(ThisObject);
	
EndProcedure

&AtClient
Procedure LabelOpenScheduleClick(Item)
	
	If Object.ScheduleOfUpdateExistsCheck = Undefined Then
		Object.ScheduleOfUpdateExistsCheck = New JobSchedule;
	EndIf;
	Dialog = New ScheduledJobDialog(Object.ScheduleOfUpdateExistsCheck);
	NotifyDescription = New NotifyDescription("LabelOpenScheduleClickEnd", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	ClearMessages();
	SettingsChanged = (Parameters.CheckUpdateExistsOnStart <> Object.CheckUpdateExistsOnStart
		AND (Parameters.CheckUpdateExistsOnStart = 1 OR Object.CheckUpdateExistsOnStart = 1))
		OR String(Parameters.ScheduleOfUpdateExistsCheck) <> String(Object.ScheduleOfUpdateExistsCheck);
		
	If SettingsChanged Then
		RepeatPeriodInDay = Object.ScheduleOfUpdateExistsCheck.RepeatPeriodInDay;
		If RepeatPeriodInDay > 0 AND RepeatPeriodInDay < 60 * 5 Then
			CommonClientServer.MessageToUser(NStr("en = 'Check interval cannot be set to more often than once every 5 minutes.'; ru = 'Интервал проверки не может быть задан чаще, чем один раз 5 минут.';pl = 'Interwału sprawdzania nie można ustawić częściej niż raz na 5 minut.';es_ES = 'No se puede establecer el control de intervalo para más frecuente de cada 5 minutos.';es_CO = 'No se puede establecer el control de intervalo para más frecuente de cada 5 minutos.';tr = 'Kontrol aralığı her 5 dakikada bir defadan daha sık ayarlanamaz.';it = 'L''intervallo di controllo non può essere impostato a più di una volta ogni 5 minuti.';de = 'Das Prüfintervall kann nicht öfter als einmal alle 5 Minuten eingestellt werden.'"));
			Return;
		EndIf;
		
		ConfigurationUpdateOptions = ApplicationParameters["StandardSubsystems.ConfigurationUpdateOptions"];
		ConfigurationUpdateOptions.CheckUpdateExistsOnStart = Object.CheckUpdateExistsOnStart;
		ConfigurationUpdateOptions.UpdateServerUserCode = Object.UpdateServerUserCode;
		ConfigurationUpdateOptions.UpdatesServerPassword = ?(Object.SaveUpdatesServerPassword, Object.UpdatesServerPassword, "");
		ConfigurationUpdateOptions.SaveUpdatesServerPassword = Object.SaveUpdatesServerPassword;
		ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck = CommonClientServer.ScheduleToStructure(Object.ScheduleOfUpdateExistsCheck);
		
		WriteSettings(ConfigurationUpdateOptions);
		ConfigurationUpdateClientDrive.EnableDisableCheckOnSchedule(Object.CheckUpdateExistsOnStart = 1 AND
			Object.ScheduleOfUpdateExistsCheck <> Undefined);
		
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure GetUserCodeAndPassword(Command)
	
	GotoURL(
		ConfigurationUpdateClientDrive.GetUpdateParameters().InfoAboutObtainingAccessToUserSitePageAddress);
	
EndProcedure
	
#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure SetScheduleVisible(Form)
	
	LabelOpenSchedule = Form.Items.LabelOpenSchedule;
	LabelOpenSchedule.Title = LabelTextOpenSchedule(Form);
	
	If Form.Object.CheckUpdateExistsOnStart = 1 Then
		LabelOpenSchedule.Enabled = True;
	Else
		LabelOpenSchedule.Enabled = False;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function LabelTextOpenSchedule(Form)
	
	StringPresentationSchedule = String(Form.Object.ScheduleOfUpdateExistsCheck);
	Return ?(NOT IsBlankString(StringPresentationSchedule),
		StringPresentationSchedule, NStr("en = 'Not defined'; ru = 'Не определена';pl = 'Nieokreślona';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non definito';de = 'Nicht definiert'"));
		
EndFunction

&AtServerNoContext
Function WriteSettings(ConfigurationUpdateOptions)
	
	DataProcessors.InstallUpdates.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions);
	RefreshReusableValues(); // Reset the cache to apply settings.
	
EndFunction

&AtClient
Procedure LabelOpenScheduleClickEnd(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		Object.ScheduleOfUpdateExistsCheck = Schedule;
	EndIf;
	
	Items.LabelOpenSchedule.Title = LabelTextOpenSchedule(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	Notify("ConfigurationUpdateSettingFormIsClosed");
	
EndProcedure

#EndRegion

