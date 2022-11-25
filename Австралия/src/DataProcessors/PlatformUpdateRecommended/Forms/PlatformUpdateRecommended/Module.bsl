
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT Parameters.Property("OpenByScenario") Then
		Raise NStr("ru='Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	SkipExit = Parameters.SkipExit;
	
	Items.MessageText.Title = Parameters.MessageText;
	Items.RecommendedPlatformVersion.Title = Parameters.RecommendedPlatformVersion;
	SystemInfo = New SystemInfo;
	ActualVersion       = SystemInfo.AppVersion;
	Min   = Parameters.MinPlatformVersion;
	Recommended = Parameters.RecommendedPlatformVersion;
	
	CannotContinue = False;
	If CommonClientServer.CompareVersions(ActualVersion, Min) < 0 Then
		TextCondition                                    = NStr("ru = 'необходимо'; en = 'required'; pl = 'jest konieczne';es_ES = 'requerido';es_CO = 'requerido';tr = 'Gerekli';it = 'richiesto';de = 'erforderlich'");
		CannotContinue                     = True;
		Items.RecommendedPlatformVersion.Title = Min;
	Else
		TextCondition                                    = NStr("ru = 'рекомендуется'; en = 'recommended'; pl = 'zalecane';es_ES = 'recomendado';es_CO = 'recomendado';tr = 'tavsiye edilir';it = 'raccomandato';de = 'empfohlen'");
		Items.RecommendedPlatformVersion.Title = Recommended;
	EndIf;
	Items.Version.Title = StringFunctionsClientServer.SubstituteParametersToString(Items.Version.Title, TextCondition, SystemInfo.AppVersion);
	
	If CannotContinue Then
		Items.QuestionText.Visible = False;
		Items.FormNo.Visible     = False;
		Title = NStr("ru = 'Необходимо обновить версию платформы'; en = '1C:Enterprise update required'; pl = 'Wymagana jest aktualizacja 1C:Enterprise';es_ES = 'Actualizar la versión de la plataforma';es_CO = 'Actualizar la versión de la plataforma';tr = '1C:Enterprise''ın güncellenmesi gerekiyor';it = 'Richiesto aggiornamento 1C:Enterprise';de = '1C:Enterprise Aktualisierung erforderlich'");
	EndIf;
	
	If (ClientApplication.CurrentInterfaceVariant() <> ClientApplicationInterfaceVariant.Taxi) Then
		Items.RecommendedPlatformVersion.Font = New Font(,, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not ActionDefined Then
		ActionDefined = True;
		
		If NOT SkipExit Then
			Terminate();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HyperlinkTextClick(Item)
	
	OpenForm("DataProcessor.PlatformUpdateRecommended.Form.PlatformUpdateOrder",,ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ContinueWork(Command)
	
	ActionDefined = True;
	Close("Continue");
	
EndProcedure

&AtClient
Procedure ExitApplication(Command)
	
	ActionDefined = True;
	If NOT SkipExit Then
		Terminate();
	EndIf;
	Close();
	
EndProcedure

#EndRegion
