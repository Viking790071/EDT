///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Variables

&AtClient
Var PreviousLanguage;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	FileInfobase = Common.FileInfobase();
	
	Source = Parameters.Source;
	If Source = "SSLAdministrationPanel" Then
		Items.OK.Title = NStr("ru = 'ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'OK';tr = 'Tamam';it = 'OK';de = 'OK'")
	EndIf;
	
	ApplicationTimeZone = GetInfoBaseTimeZone();
	If IsBlankString(ApplicationTimeZone) Then
		ApplicationTimeZone = TimeZone();
	EndIf;
	Items.ApplicationTimeZone.ChoiceList.LoadValues(GetAvailableTimeZones());
	
	SetMainLanguage();
	
	Settings = New Structure;
	Settings.Insert("AdditionalLanguageCode1", "");
	Settings.Insert("AdditionalLanguageCode2", "");
	Settings.Insert("AdditionalLanguageCode3", "");
	Settings.Insert("AdditionalLanguageCode4", "");
	Settings.Insert("MultilanguageData",      True);
	
	NationalLanguageSupportOverridable.OnDefineSettings(Settings);
	
	LanguagesCount = Metadata.Languages.Count();
	If Not Settings.MultilanguageData OR LanguagesCount = 1 Then
		Items.AdditionalLanguagesGroup.Visible = False;
		Items.MainLanguageGroup.Visible        = False;
	Else
		If LanguagesCount = 2 Then
			Items.AdditionalLanguage2Group.Visible = False;
			Items.AdditionalLanguage3Group.Visible = False;
			Items.AdditionalLanguage4Group.Visible = False;
		ElsIf LanguagesCount = 3 Then
			Items.AdditionalLanguage3Group.Visible = False;
			Items.AdditionalLanguage4Group.Visible = False;
		ElsIf LanguagesCount = 4 Then
			Items.AdditionalLanguage4Group.Visible = False;
		EndIf;
		DisplayAdditionalLanguagesSettings(Settings, LanguagesCount);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If FileInfobase
		AND StrFind(LaunchParameter, "UpdateAndExit") > 0 Then
			AttachIdleHandler("SetDefaultValues", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetMainLanguage()
	
	DefaultLanguage = Constants.DefaultLanguage.Get();
	For each Language In Metadata.Languages Do
		Items.DefaultLanguage.ChoiceList.Add(Language.LanguageCode, Language.Presentation());
	EndDo;
	
	If IsBlankString(DefaultLanguage) Then
		DefaultLanguage = CurrentLanguage().LanguageCode;
	EndIf;
	
	If IsBlankString(DefaultLanguage) Or Items.DefaultLanguage.ChoiceList.FindByValue(DefaultLanguage) = Undefined Then
		DefaultLanguage = NationalLanguageSupportClientServer.DefaultLanguageCode();
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayAdditionalLanguagesSettings(Settings, LanguagesCount)
	
	AvailableLanguages = New Map;
	For each ConfigurationLanguage In Metadata.Languages Do
		If StrCompare(DefaultLanguage, ConfigurationLanguage.LanguageCode) = 0 Then
			Continue;
		EndIf;
		AvailableLanguages.Insert(ConfigurationLanguage.LanguageCode, True);
	EndDo;
	
	DefaultLanguage1 = "";
	If ValueIsFilled(Settings.AdditionalLanguageCode1) Then
		If AvailableLanguages.Get(Settings.AdditionalLanguageCode1) = True Then
			DefaultLanguage1 = Settings.AdditionalLanguageCode1;
		EndIf;
	EndIf;
	
	DefaultLanguage2 = "";
	If LanguagesCount > 2 AND ValueIsFilled(Settings.AdditionalLanguageCode2) Then
		If AvailableLanguages.Get(Settings.AdditionalLanguageCode2) = True Then
			DefaultLanguage2 = Settings.AdditionalLanguageCode2;
		EndIf;
	EndIf;
	
	DefaultLanguage3 = "";
	If LanguagesCount > 3 AND ValueIsFilled(Settings.AdditionalLanguageCode3) Then
		If AvailableLanguages.Get(Settings.AdditionalLanguageCode3) = True Then
			DefaultLanguage3 = Settings.AdditionalLanguageCode3;
		EndIf;
	EndIf;

	DefaultLanguage4 = "";
	If LanguagesCount > 4 AND ValueIsFilled(Settings.AdditionalLanguageCode4) Then
		If AvailableLanguages.Get(Settings.AdditionalLanguageCode4) = True Then
			DefaultLanguage4 = Settings.AdditionalLanguageCode4;
		EndIf;
	EndIf;
	
	For each Language In Metadata.Languages Do
		If StrCompare(Language.LanguageCode, DefaultLanguage) <> 0 Then
			If IsBlankString(DefaultLanguage1) Then
				DefaultLanguage1 = Language.LanguageCode;
			ElsIf IsBlankString(DefaultLanguage2)
				AND Language.LanguageCode <> DefaultLanguage1
				AND Language.LanguageCode <> DefaultLanguage3
				AND Language.LanguageCode <> DefaultLanguage4 Then
				DefaultLanguage2 = Language.LanguageCode;
			ElsIf IsBlankString(DefaultLanguage3)
				AND Language.LanguageCode <> DefaultLanguage1
				AND Language.LanguageCode <> DefaultLanguage2
				AND Language.LanguageCode <> DefaultLanguage4 Then
				DefaultLanguage3 = Language.LanguageCode;
			ElsIf IsBlankString(DefaultLanguage4)
				AND Language.LanguageCode <> DefaultLanguage1
				AND Language.LanguageCode <> DefaultLanguage2
				AND Language.LanguageCode <> DefaultLanguage3 Then
				DefaultLanguage4 = Language.LanguageCode;
			EndIf;
		EndIf;
		Items.AdditionalLanguage1.ChoiceList.Add(Language.LanguageCode, Language.Presentation());
		Items.AdditionalLanguage2.ChoiceList.Add(Language.LanguageCode, Language.Presentation());
		Items.AdditionalLanguage3.ChoiceList.Add(Language.LanguageCode, Language.Presentation());
		Items.AdditionalLanguage4.ChoiceList.Add(Language.LanguageCode, Language.Presentation());
	EndDo;
	
	UseAdditionalLanguage1 = NativeLanguagesSupportServer.FirstAdditionalLanguageUsed();
	UseAdditionalLanguage2 = NativeLanguagesSupportServer.SecondAdditionalLanguageUsed();
	UseAdditionalLanguage3 = NativeLanguagesSupportServer.ThirdAdditionalLanguageUsed();
	UseAdditionalLanguage4 = NativeLanguagesSupportServer.FourthAdditionalLanguageUsed();
	
	AdditionalLanguage1 = NativeLanguagesSupportServer.FirstAdditionalInfobaseLanguageCode();
	AdditionalLanguage2 = NativeLanguagesSupportServer.SecondAdditionalInfobaseLanguageCode();
	AdditionalLanguage3 = NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode();
	AdditionalLanguage4 = NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode();

	Items.AdditionalLanguage1.Enabled = UseAdditionalLanguage1 And IsBlankString(AdditionalLanguage1);
	Items.AdditionalLanguage2.Enabled = UseAdditionalLanguage2 And IsBlankString(AdditionalLanguage2);
	Items.AdditionalLanguage3.Enabled = UseAdditionalLanguage3 And IsBlankString(AdditionalLanguage3);
	Items.AdditionalLanguage4.Enabled = UseAdditionalLanguage4 And IsBlankString(AdditionalLanguage4);
	
	If IsBlankString(AdditionalLanguage1) Then
		AdditionalLanguage1 = DefaultLanguage1;
	EndIf;
	
	If LanguagesCount > 2 AND IsBlankString(AdditionalLanguage2) Then
		AdditionalLanguage2 = DefaultLanguage2;
	EndIf;

	If LanguagesCount > 3 AND IsBlankString(AdditionalLanguage3) Then
		AdditionalLanguage3 = DefaultLanguage3;
	EndIf;

	If LanguagesCount > 4 AND IsBlankString(AdditionalLanguage4) Then
		AdditionalLanguage4 = DefaultLanguage4;
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseAdditionalLanguage1OnChange(Item)
	UseAdditionalLanguage1OnChangeAtServer();
EndProcedure

&AtClient
Procedure UseAdditionalLanguage2OnChange(Item)
	UseAdditionalLanguage2OnChangeAtServer();
EndProcedure

&AtClient
Procedure UseAdditionalLanguage3OnChange(Item)
	UseAdditionalLanguage3OnChangeAtServer();
EndProcedure

&AtClient
Procedure UseAdditionalLanguage4OnChange(Item)
	UseAdditionalLanguage4OnChangeAtServer();
EndProcedure

&AtClient
Procedure MainLanguageOnChange(Item)
	
	If StrCompare(PreviousLanguage, DefaultLanguage) <> 0 Then
		If StrCompare(AdditionalLanguage1, DefaultLanguage) = 0 Then
			AdditionalLanguage1 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage2, DefaultLanguage) = 0 Then
			AdditionalLanguage2 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage3, DefaultLanguage) = 0 Then
			AdditionalLanguage3 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage4, DefaultLanguage) = 0 Then
			AdditionalLanguage4 = PreviousLanguage;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MainLanguageStartChoice(Item, ChoiceData, StandardProcessing)
	PreviousLanguage = DefaultLanguage;
EndProcedure

&AtClient
Procedure AdditionalLanguage1OnChange(Item)
	
	If StrCompare(PreviousLanguage, AdditionalLanguage1) <> 0 Then
		If StrCompare(AdditionalLanguage1, DefaultLanguage) = 0 Then
			DefaultLanguage = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage1, AdditionalLanguage2) = 0 Then
			AdditionalLanguage2 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage1, AdditionalLanguage3) = 0 Then
			AdditionalLanguage3 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage1, AdditionalLanguage4) = 0 Then
			AdditionalLanguage4 = PreviousLanguage;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure AdditionalLanguage2OnChange(Item)
	
	If StrCompare(PreviousLanguage, AdditionalLanguage2) <> 0 Then
		If StrCompare(AdditionalLanguage2, AdditionalLanguage1) = 0 Then
			AdditionalLanguage1 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage2, AdditionalLanguage3) = 0 Then
			AdditionalLanguage3 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage2, AdditionalLanguage4) = 0 Then
			AdditionalLanguage4 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage2, DefaultLanguage) = 0 Then
			DefaultLanguage = PreviousLanguage;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure AdditionalLanguage3OnChange(Item)
	
	If StrCompare(PreviousLanguage, AdditionalLanguage3) <> 0 Then
		If StrCompare(AdditionalLanguage3, AdditionalLanguage1) = 0 Then
			AdditionalLanguage1 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage3, AdditionalLanguage2) = 0 Then
			AdditionalLanguage2 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage3, AdditionalLanguage4) = 0 Then
			AdditionalLanguage4 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage3, DefaultLanguage) = 0 Then
			DefaultLanguage = PreviousLanguage;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure AdditionalLanguage4OnChange(Item)
	
	If StrCompare(PreviousLanguage, AdditionalLanguage4) <> 0 Then
		If StrCompare(AdditionalLanguage4, AdditionalLanguage1) = 0 Then
			AdditionalLanguage1 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage4, AdditionalLanguage2) = 0 Then
			AdditionalLanguage2 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage4, AdditionalLanguage3) = 0 Then
			AdditionalLanguage3 = PreviousLanguage;
		ElsIf StrCompare(AdditionalLanguage4, DefaultLanguage) = 0 Then
			DefaultLanguage = PreviousLanguage;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure AdditionalLanguage1StartChoice(Item, ChoiceData, StandardProcessing)
	PreviousLanguage = AdditionalLanguage1;
EndProcedure

&AtClient
Procedure AdditionalLanguage2StartChoice(Item, ChoiceData, StandardProcessing)
	PreviousLanguage = AdditionalLanguage2;
EndProcedure

&AtClient
Procedure AdditionalLanguage3StartChoice(Item, ChoiceData, StandardProcessing)
	PreviousLanguage = AdditionalLanguage3;
EndProcedure

&AtClient
Procedure AdditionalLanguage4StartChoice(Item, ChoiceData, StandardProcessing)
	PreviousLanguage = AdditionalLanguage4;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	If DataCorrect() Then
		
		If Source = "SSLAdministrationPanel" AND ConstantsValuesChanged() Then
			RefillData();
		Else
			WriteConstantsValues();
			Close(New Structure("Cancel", False));
		EndIf;
		
	Else
		ShowMessageBox(Undefined, NStr("ru = 'Указаны некорректные значения региональных настроек.'; en = 'Invalid regional settings.'; pl = 'Nieprawidłowe ustawienia regionalne';es_ES = 'Ajustes regionales no válidos.';es_CO = 'Ajustes regionales no válidos.';tr = 'Geçersiz bölge ayarları.';it = 'I valori delle impostazioni regionali indicati non sono corretti.';de = 'Ungültige lokale Einstellungen.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetDefaultValues()
	
	WriteConstantsValues();
	Close(New Structure("Cancel", False));
	
EndProcedure

&AtClient
Procedure RefillData()
	
	ClearMessages();
	
	Items.Pages.CurrentPage = Items.Wait;
	Items.OK.Enabled = False;
	
	ExecutionProgressNotification = New NotifyDescription("ExecutionProgress", ThisObject);
	
	Job = StartBackgroundRefillingAtServer(UUID);
	JobID = Job.JobID;
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	WaitSettings.ExecutionProgressNotification = ExecutionProgressNotification;
	
	Handler = New NotifyDescription("AfterRefillInBackground", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(Job, Handler, WaitSettings);
	
EndProcedure

&AtServer
Function StartBackgroundRefillingAtServer(Val UUID)
	
	WriteConstantsValues();
	MethodParameters = New Structure;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Перезаполнение строк предопределенных элементов и классификаторов.'; en = 'Refill predefined item strings and classifier strings.'; pl = 'Uzupełnij predefiniowane wiersze pozycji i wiersze klasyfikatora.';es_ES = 'Rellenar líneas de artículos predefinidos y líneas de clasificación.';es_CO = 'Rellenar líneas de artículos predefinidos y líneas de clasificación.';tr = 'Önceden tanımlanmış öğe ve sınıflandırıcı sıralarını yeniden doldur.';it = 'Ricompilazione delle righe degli elementi predefiniti e dei classificatori.';de = 'Vorbestimmte Position-Zeichenfolgen und Klassifikatore wieder ausfüllen.'");
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground("NativeLanguagesSupportServer.RefillMultilanguageStringsInObjects",
		MethodParameters, ExecutionParameters);
		
	Return BackgroundJob;
EndFunction

&AtClient
Procedure AfterRefillInBackground(Job, AdditionalParameters) Export
	
	If Job = Undefined Then
		Return;
	EndIf;
	
	If Job.Status = "Completed" Then
	Items.Pages.CurrentPage = Items.CompletedSuccessfully;
		RefreshReusableValues();
		
		Items.OK.Visible = True;
		Items.Close.Visible = True;
		Items.Close.DefaultButton = True;
		CurrentItem = Items.Close;
	ElsIf Job.Status = "Error" Then
		Items.Pages.CurrentPage = Items.RegionalSettings;
		ErrorText = NStr("ru = 'Не удается перезаполнить строки предопределенных элементов и классификаторов.'; en = 'Cannot refill predefined item strings and classifier strings.'; pl = 'Nie można uzupełnić wierszy pozycji i wierszy klasyfikatora.';es_ES = 'No puede rellenar líneas de artículos predefinidos y líneas de clasificación.';es_CO = 'No puede rellenar líneas de artículos predefinidos y líneas de clasificación.';tr = 'Önceden tanımlanmış öğe ve sınıflandırıcı sıraları yeniden doldurulamıyor.';it = 'Impossibile ricompilare le righe degli elementi predefiniti e dei classificatori.';de = 'Wiederausfüllen von vorbestimmten Positionszeichenfolgen und Klassifikatoren ist nicht möglich.'");
		ErrorText = ErrorText + Chars.LF + NStr("ru = 'Техническая информация:'; en = 'Technical details:'; pl = 'Szczegóły techniczne:';es_ES = 'Detalles técnicos:';es_CO = 'Detalles técnicos:';tr = 'Teknik detaylar:';it = 'Informazione tecnica:';de = 'Technische Details:'") + Job.DetailedErrorPresentation;
		CommonClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ReadProgress(JobID)
	Return TimeConsumingOperations.ReadProgress(JobID);
EndFunction

&AtClient
Procedure ExecutionProgress(Result, AdditionalParameters) Export
	
	If Result.Status = "Running" Then
		Progress = ReadProgress(Result.JobID);
		If Progress <> Undefined Then
			CleanupStatusText = Progress.Text;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Function DataCorrect()
	
	If IsBlankString(DefaultLanguage) Then
		Return False;
	EndIf;
	
	If IsBlankString(ApplicationTimeZone) Then
		Return False;
	EndIf;
	
	LanguagesThatWereSet = New Map;
	LanguagesThatWereSet.Insert(DefaultLanguage, True);
	
	If UseAdditionalLanguage1 Then
		If DefaultLanguage = AdditionalLanguage1
			Or (AdditionalLanguage1 = AdditionalLanguage2 And UseAdditionalLanguage2)
			Or (AdditionalLanguage1 = AdditionalLanguage3 And UseAdditionalLanguage3)
			Or (AdditionalLanguage1 = AdditionalLanguage4 And UseAdditionalLanguage4) Then
			Return False;
		EndIf;
	EndIf;
	
	If UseAdditionalLanguage2 Then
		If DefaultLanguage = AdditionalLanguage2
			Or (AdditionalLanguage2 = AdditionalLanguage1 And UseAdditionalLanguage1)
			Or (AdditionalLanguage2 = AdditionalLanguage3 And UseAdditionalLanguage3)
			Or (AdditionalLanguage2 = AdditionalLanguage4 And UseAdditionalLanguage4) Then
			Return False;
		EndIf;
	EndIf;
	
	If UseAdditionalLanguage3 Then
		If DefaultLanguage = AdditionalLanguage3
			Or (AdditionalLanguage3 = AdditionalLanguage1 And UseAdditionalLanguage1)
			Or (AdditionalLanguage3 = AdditionalLanguage2 And UseAdditionalLanguage2)
			Or (AdditionalLanguage3 = AdditionalLanguage4 And UseAdditionalLanguage4) Then
			Return False;
		EndIf;
	EndIf;	
	
	If UseAdditionalLanguage4 Then
		If DefaultLanguage = AdditionalLanguage4
			Or (AdditionalLanguage4 = AdditionalLanguage1 And UseAdditionalLanguage1)
			Or (AdditionalLanguage4 = AdditionalLanguage2 And UseAdditionalLanguage2)
			Or (AdditionalLanguage4 = AdditionalLanguage3 And UseAdditionalLanguage3) Then
			Return False;
		EndIf;
	EndIf; 
	
	Return True;
	
EndFunction

&AtServer
Procedure WriteConstantsValues()
	
	If ApplicationTimeZone <> GetInfoBaseTimeZone() Then
		SetPrivilegedMode(True);
		Try
			SetExclusiveMode(True);
			SetInfoBaseTimeZone(ApplicationTimeZone);
			SetExclusiveMode(False);
		Except
			SetExclusiveMode(False);
			Raise;
		EndTry;
		SetPrivilegedMode(False);
		SetSessionTimeZone(ApplicationTimeZone);
	EndIf;
	
	Constants.DefaultLanguage.Set(DefaultLanguage);
	SessionParameters.DefaultLanguage = DefaultLanguage;
	
	Language1Code = ?(UseAdditionalLanguage1, AdditionalLanguage1, "");
	Constants.AdditionalLanguage1.Set(Language1Code);
	Constants.UseAdditionalLanguage1.Set(UseAdditionalLanguage1);
	
	Language2Code = ?(UseAdditionalLanguage2, AdditionalLanguage2, "");
	Constants.AdditionalLanguage2.Set(Language2Code);
	Constants.UseAdditionalLanguage2.Set(UseAdditionalLanguage2);
	
	Language3Code = ?(UseAdditionalLanguage3, AdditionalLanguage3, "");
	Constants.AdditionalLanguage3.Set(Language3Code);
	Constants.UseAdditionalLanguage3.Set(UseAdditionalLanguage3);
	
	Language4Code = ?(UseAdditionalLanguage4, AdditionalLanguage4, "");
	Constants.AdditionalLanguage4.Set(Language4Code);
	Constants.UseAdditionalLanguage4.Set(UseAdditionalLanguage4);
	
EndProcedure

&AtServer
Function ConstantsValuesChanged()
	
	If StrCompare(Constants.DefaultLanguage.Get(), DefaultLanguage) <> 0 Then
		Return True;
	EndIf;
	
	If (Constants.UseAdditionalLanguage1.Get() = False AND UseAdditionalLanguage1 = True)
		Or (Constants.UseAdditionalLanguage2.Get() = False AND UseAdditionalLanguage2 = True)
		Or (Constants.UseAdditionalLanguage3.Get() = False AND UseAdditionalLanguage3 = True)
		Or (Constants.UseAdditionalLanguage4.Get() = False AND UseAdditionalLanguage4 = True) Then
			Return True;
	EndIf;
	
	If UseAdditionalLanguage1
		AND StrCompare(Constants.AdditionalLanguage1.Get(), AdditionalLanguage1) <> 0 Then
			Return True;
	EndIf;
	
	If UseAdditionalLanguage2
		AND StrCompare(Constants.AdditionalLanguage2.Get(), AdditionalLanguage2) <> 0 Then
			Return True;
	EndIf;

	If UseAdditionalLanguage3
		AND StrCompare(Constants.AdditionalLanguage3.Get(), AdditionalLanguage3) <> 0 Then
			Return True;
	EndIf;
	
	If UseAdditionalLanguage4
		AND StrCompare(Constants.AdditionalLanguage4.Get(), AdditionalLanguage4) <> 0 Then
			Return True;
	EndIf;

	Return False;
	
EndFunction

&AtServer
Procedure UseAdditionalLanguage1OnChangeAtServer()
	
	AdditionalLanguage1Stored = NativeLanguagesSupportServer.FirstAdditionalInfobaseLanguageCode();
	Items.AdditionalLanguage1.Enabled = UseAdditionalLanguage1 And IsBlankString(AdditionalLanguage1Stored);
	
EndProcedure

&AtServer
Procedure UseAdditionalLanguage2OnChangeAtServer()
	
	AdditionalLanguage2Stored = NativeLanguagesSupportServer.SecondAdditionalInfobaseLanguageCode();
	Items.AdditionalLanguage2.Enabled = UseAdditionalLanguage2 And IsBlankString(AdditionalLanguage2Stored);
	
EndProcedure

&AtServer
Procedure UseAdditionalLanguage3OnChangeAtServer()
	
	AdditionalLanguage3Stored = NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode();
	Items.AdditionalLanguage3.Enabled = UseAdditionalLanguage3 And IsBlankString(AdditionalLanguage3Stored);
	
EndProcedure

&AtServer
Procedure UseAdditionalLanguage4OnChangeAtServer()
	
	AdditionalLanguage4Stored = NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode();
	Items.AdditionalLanguage4.Enabled = UseAdditionalLanguage4 And IsBlankString(AdditionalLanguage4Stored);
	
EndProcedure

#EndRegion