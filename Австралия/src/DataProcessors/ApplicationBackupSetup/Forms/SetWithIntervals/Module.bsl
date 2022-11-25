#Region Variables

&AtClient
Var AnswerBeforeClose;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Cancel = True;
		Raise NStr("ru = 'Для корректной работы необходим режим толстого, тонкого или ВЕБ-клиента.'; en = 'Thin, thick, or web client mode is required.'; pl = 'Do prawidłowego działania wymagany jest gruby, cienki tryb klienta lub tryb klienta WEB.';es_ES = 'Para el funcionamiento correcto es necesario el modo del cliente grueso, ligero o cliente web.';es_CO = 'Para el funcionamiento correcto es necesario el modo del cliente grueso, ligero o cliente web.';tr = 'Doğu çalışma için kalın, ince veya WEB istemci modu gerekmektedir.';it = 'La modalità Thin, thick, o web client è richiesta.';de = 'Für den korrekten Betrieb ist es notwendig, den Thick-, Thin- oder WEB-Client Modus zu verwenden.'");
		
	EndIf;
	
	// Form initialization
	For MonthNumber = 1 To 12 Do
		Items.EarlyBackupMonth.ChoiceList.Add(MonthNumber, 
			Format(Date(2, MonthNumber, 1), "DF=MMMM"));
	EndDo;
	
	SetLabelWidth();
	
	ApplySettingRestrictions();
	
	FillFormBySettings(Parameters.SettingsData);
	
EndProcedure

&AtClient
Procedure DailyBackupCountOnChange(Item)
	
	DailyBackupsCountLabel = BackupCountLabel(DailyBackupCount);
	
EndProcedure

&AtClient
Procedure MonthlyBackupCountOnChange(Item)
	
	MonthlyBackupsCountLabel = BackupCountLabel(MonthlyBackupCount);
	
EndProcedure

&AtClient
Procedure YearlyBackupCountOnChange(Item)
	
	AnnualBackupsCountLabel = BackupCountLabel(YearlyBackupCount);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	If AnswerBeforeClose = True Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("BeforeCloseCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Данные были изменены. Сохранить изменения?'; en = 'The data was changed. Do you want to save the changes?'; pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Volete salvare le modifiche?';de = 'Daten wurden geändert. Wollen Sie die Änderungen speichern?'"), 
		QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
		
EndProcedure
		
#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Reread(Command)
	
	RereadAtServer();
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	SaveNewSettings();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	SaveNewSettings();
	Close();
	
EndProcedure

&AtClient
Procedure SetStandardSettings(Command)
	
	SetStandardSettingsAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RereadAtServer()
	
	FillFormBySettings(
		DataAreaBackupFormDataInterface.GetAreaSettings(Parameters.DataArea));
		
	Modified = False;
	
EndProcedure

&AtServer
Procedure FillFormBySettings(Val SettingsData, Val UpdateInitialSettings = True)
	
	FillPropertyValues(ThisObject, SettingsData);
	
	If UpdateInitialSettings Then
		InitialSettings = SettingsData;
	EndIf;
	
	SetAllNumberLabels();
	
EndProcedure

&AtServer
Procedure SetLabelWidth()
	
	MaxWidth = 0;
	
	NumberForCheck = New Array;
	NumberForCheck.Add(1);
	NumberForCheck.Add(2);
	NumberForCheck.Add(5);
	
	For Each Number In NumberForCheck Do
		LabelWidth = StrLen(BackupCountLabel(Number));
		If LabelWidth > MaxWidth Then
			MaxWidth = LabelWidth;
		EndIf;
	EndDo;
	
	LabelItems = New Array;
	LabelItems.Add(Items.DailyBackupsCountLabel);
	LabelItems.Add(Items.MonthlyBackupsCountLabel);
	LabelItems.Add(Items.AnnualBackupsCountLabel);
	
	For each SignatureItem In LabelItems Do
		SignatureItem.Width = MaxWidth;
	EndDo;
	
EndProcedure

&AtServer
Procedure ApplySettingRestrictions()
	
	SettingsRestrictions = Parameters.SettingsRestrictions;
	
	TooltipPattern = NStr("ru = 'Максимум %1'; en = 'Maximum %1'; pl = 'Maksymalny %1';es_ES = 'Máximo %1';es_CO = 'Máximo %1';tr = 'Maksimum %1';it = 'Massimo %1';de = 'Maximal %1'");
	
	RestrictionItems = New Structure;
	RestrictionItems.Insert("DailyBackupCount", "DailyBackupMax");
	RestrictionItems.Insert("MonthlyBackupCount", "MonthlyBackupMax");
	RestrictionItems.Insert("YearlyBackupCount", "YearlyBackupMax");
	
	For each KeyAndValue In RestrictionItems Do
		Item = Items[KeyAndValue.Key];
		Item.MaxValue = SettingsRestrictions[KeyAndValue.Value];
		Item.ToolTip = 
			StringFunctionsClientServer.SubstituteParametersToString(TooltipPattern, 
				SettingsRestrictions[KeyAndValue.Value]);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetAllNumberLabels()
	
	DailyBackupsCountLabel = BackupCountLabel(DailyBackupCount);
	MonthlyBackupsCountLabel = BackupCountLabel(MonthlyBackupCount);
	AnnualBackupsCountLabel = BackupCountLabel(YearlyBackupCount);
	
EndProcedure

&AtClientAtServerNoContext
Function BackupCountLabel(Val Count)

	PresentationsArray = New Array;
	PresentationsArray.Add(NStr("ru = 'последнюю копию'; en = 'the latest copy'; pl = 'ostatnia kopia';es_ES = 'última copia';es_CO = 'última copia';tr = 'son kopya';it = 'l''ultimissima copia';de = 'letzte Kopie'"));
	PresentationsArray.Add(NStr("ru = 'последние копии'; en = 'last copies'; pl = 'ostatnie kopie';es_ES = 'últimas copias';es_CO = 'últimas copias';tr = 'son kopyalar';it = 'ultime copie';de = 'letzte kopien'"));
	PresentationsArray.Add(NStr("ru = 'последние копии'; en = 'last copies'; pl = 'ostatnie kopie';es_ES = 'últimas copias';es_CO = 'últimas copias';tr = 'son kopyalar';it = 'ultime copie';de = 'letzte kopien'"));
	
	If Count >= 100 Then
		Count = Count - Int(Count / 100)*100;
	EndIf;
	
	If Count > 20 Then
		Count = Count - Int(Count/10)*10;
	EndIf;
	
	If Count = 1 Then
		Result = PresentationsArray[0];
	ElsIf Count > 1 AND Count < 5 Then
		Result = PresentationsArray[1];
	Else
		Result = PresentationsArray[2];
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveNewSettings()
	
	NewSettings = New Structure;
	For each KeyAndValue In InitialSettings Do
		NewSettings.Insert(KeyAndValue.Key, ThisObject[KeyAndValue.Key]);
	EndDo;
	
	NewSettings = New FixedStructure(NewSettings);
	
	DataAreaBackupFormDataInterface.SetAreaSettings(
		Parameters.DataArea,
		NewSettings,
		InitialSettings);
		
	Modified = False;
	InitialSettings = NewSettings;
	
EndProcedure

&AtServer
Procedure SetStandardSettingsAtServer()
	
	FillFormBySettings(
		DataAreaBackupFormDataInterface.GetStandardSettings(),
		False);
	
EndProcedure

&AtClient
Procedure BeforeCloseCompletion(Response, AdditionalParameters) Export	
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response = DialogReturnCode.Yes Then
		SaveNewSettings();
	EndIf;
	AnswerBeforeClose = True;
    Close();
	
EndProcedure

#EndRegion
