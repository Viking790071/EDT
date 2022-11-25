#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SubsystemSettings  = InfobaseUpdateInternal.SubsystemSettings();
	FormAddressInApplication = SubsystemSettings.ApplicationReleaseNotesLocation;
	
	If ValueIsFilled(FormAddressInApplication) Then
		Items.FormAddressInApplication.Title = FormAddressInApplication;
	EndIf;
	
	If Not Parameters.ShowOnlyChanges Then
		Items.FormAddressInApplication.Visible = False;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Что нового в конфигурации %1'; en = 'What''s new in %1'; pl = 'Co nowego w %1';es_ES = 'Qué hay de nuevo en %1';es_CO = 'Qué hay de nuevo en %1';tr = 'Yapılandırmadaki yenilikler%1';it = 'Cosa c''è di nuovo in %1';de = 'Was ist neu in %1'"), Metadata.Synonym);
	
	If ValueIsFilled(Parameters.UpdateStartTime) Then
		UpdateStartTime = Parameters.UpdateStartTime;
		UpdateEndTime = Parameters.UpdateEndTime;
	EndIf;
	
	Sections = InfobaseUpdateInternal.NotShownUpdateDetailSections();
	LatestVersion = InfobaseUpdateInternal.SystemChangesDisplayLastVersion();
	
	If Sections.Count() = 0 Then
		DocumentUpdateDetails = Metadata.CommonTemplates.Find("ApplicationReleaseNotes");
		If DocumentUpdateDetails <> Undefined
			AND (LatestVersion = Undefined
				Or Not Parameters.ShowOnlyChanges) Then
			AllSections = InfobaseUpdateInternal.UpdateDetailsSections();
			If TypeOf(AllSections) = Type("ValueList")
				AND AllSections.Count() <> 0 Then
				For Each Item In AllSections Do
					Sections.Add(Item.Presentation);
				EndDo;
				DocumentUpdateDetails = InfobaseUpdateInternal.DocumentUpdateDetails(Sections);
			Else
				DocumentUpdateDetails = GetCommonTemplate(DocumentUpdateDetails);
			EndIf;
		Else
			DocumentUpdateDetails = New SpreadsheetDocument();
		EndIf;
	Else
		DocumentUpdateDetails = InfobaseUpdateInternal.DocumentUpdateDetails(Sections);
	EndIf;
	
	If DocumentUpdateDetails.TableHeight = 0 Then
		Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Конфигурация успешно обновлена на версию %1'; en = 'The application is updated to version %1.'; pl = 'Konfiguracja została pomyślnie zaktualizowana do wersji %1';es_ES = 'La versión de la aplicación se ha actualizado con éxito para la versión %1';es_CO = 'La versión de la aplicación se ha actualizado con éxito para la versión %1';tr = 'Uygulama, %1 sürümüne güncellendi.';it = 'L''applicazione è aggiornata alla versione %1.';de = 'Die Anwendungsversion wurde erfolgreich auf Version %1 aktualisiert'"), Metadata.Version);
		DocumentUpdateDetails.Area("R1C1:R1C1").Text = Text;
	EndIf;
	
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If NOT ValueIsFilled(SubsystemDetails.MainServerModule) Then
			Continue;
		EndIf;
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnPrepareUpdateDetailsTemplate(DocumentUpdateDetails);
	EndDo;
	InfobaseUpdateOverridable.OnPrepareUpdateDetailsTemplate(DocumentUpdateDetails);
	
	UpdateDetails.Clear();
	UpdateDetails.Put(DocumentUpdateDetails);
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	UpdateStartTime = UpdateInfo.UpdateStartTime;
	UpdateEndTime = UpdateInfo.UpdateEndTime;
	
	If Not Common.SeparatedDataUsageAvailable()
		Or UpdateInfo.DeferredUpdateCompletedSuccessfully <> Undefined
		Or UpdateInfo.HandlersTree <> Undefined
			AND UpdateInfo.HandlersTree.Rows.Count() = 0 Then
		Items.DeferredUpdate.Visible = False;
	EndIf;
	
	If Common.FileInfobase() Then
		MessageTitle = NStr("ru = 'Необходимо выполнить дополнительные процедуры обработки данных'; en = 'Additional data processing required'; pl = 'Wykonaj dodatkowe procedury przetwarzania danych';es_ES = 'Ejecutar los procedimientos del procesamiento de datos adicionales';es_CO = 'Ejecutar los procedimientos del procesamiento de datos adicionales';tr = 'Ek veri işleme prosedürlerini yürütme';it = 'Richiesta elaborazione dati aggiuntiva';de = 'Führen Sie zusätzliche Datenverarbeitungsverfahren aus'");
		Items.DeferredDataUpdate.Title = MessageTitle;
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		Items.DeferredDataUpdate.Title =
			NStr("ru = 'Не выполнены дополнительные процедуры обработки данных'; en = 'Additional data processing skipped'; pl = 'Dodatkowe procedury przetwarzania danych nie zostały wykonane';es_ES = 'Procedimientos del procesamiento de datos adicionales no se han ejecutado';es_CO = 'Procedimientos del procesamiento de datos adicionales no se han ejecutado';tr = 'Ek veri işleme prosedürleri uygulanmadı';it = 'Saltata elaborazione dati aggiuntiva';de = 'Zusätzliche Datenverarbeitungsprozeduren wurden nicht ausgeführt'");
	EndIf;
	
	If Not ValueIsFilled(UpdateStartTime) AND Not ValueIsFilled(UpdateEndTime) Then
		Items.TechnicalInformationOnUpdateResult.Visible = False;
	ElsIf Users.IsFullUser() AND Not Common.DataSeparationEnabled() Then
		Items.TechnicalInformationOnUpdateResult.Visible = True;
	Else
		Items.TechnicalInformationOnUpdateResult.Visible = False;
	EndIf;
	
	ClientServerInfobase = Not Common.FileInfobase();
	
	// Displaying the information on disabled scheduled jobs.
	If Not ClientServerInfobase
		AND Users.IsFullUser(, True) Then
		ClientLaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
		ScheduledJobsDisabled = StrFind(ClientLaunchParameter, "ScheduledJobsDisabled") <> 0;
		If Not ScheduledJobsDisabled Then
			Items.ScheduledJobsDisabledGroup.Visible = False;
		EndIf;
	Else
		Items.ScheduledJobsDisabledGroup.Visible = False;
	EndIf;
	
	Items.UpdateDetails.HorizontalScrollBar = ScrollBarUse.DontUse;
	
	InfobaseUpdateInternal.SetShowDetailsToCurrentVersionFlag();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ClientServerInfobase Then
		AttachIdleHandler("UpdateDeferredUpdateStatus", 60);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UpdateDetailsChoice(Item, Area, StandardProcessing)
	
	If StrFind(Area.Text, "http://") = 1 Or StrFind(Area.Text, "https://") = 1 Then
		CommonClient.OpenURL(Area.Text);
	EndIf;
	
	InfobaseUpdateClientOverridable.OnClickUpdateDetailsDocumentHyperlink(Area);
	
EndProcedure

&AtClient
Procedure ShowUpdateResultInfoClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowErrorsAndWarnings", True);
	FormParameters.Insert("StartDate", UpdateStartTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeferredDataUpdate(Command)
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.DeferredIBUpdateProgressIndicator");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateDeferredUpdateStatus()
	
	UpdateDeferredUpdateStatusAtServer();
	
EndProcedure

&AtServer
Procedure UpdateDeferredUpdateStatusAtServer()
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdateEndTime <> Undefined Then
		Items.DeferredUpdate.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure URLProcessingScheduledJobsDisabled(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	Notification = New NotifyDescription("DisabledScheduledJobsURLProcessingCompletion", ThisObject);
	QuestionText = NStr("ru = 'Перезапустить программу?'; en = 'Do you want to restart the application?'; pl = 'Zrestartować aplikację?';es_ES = '¿Reiniciar la aplicación?';es_CO = '¿Reiniciar la aplicación?';tr = 'Uygulama yeniden başlatılsın mı?';it = 'Volete riavviare l''applicazione?';de = 'Neustart der Anwendung?'");
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo,, DialogReturnCode.No);
EndProcedure

&AtClient
Procedure DisabledScheduledJobsURLProcessingCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		NewStartupParameter = StrReplace(LaunchParameter, "ScheduledJobsDisabled", "");
		NewStartupParameter = StrReplace(NewStartupParameter, "StartInfobaseUpdate", "");
		NewStartupParameter = "/C """ + NewStartupParameter + """";
		Terminate(True, NewStartupParameter);
	EndIf;
	
EndProcedure

#EndRegion
