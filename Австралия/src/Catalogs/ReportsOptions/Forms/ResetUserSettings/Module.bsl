
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("Variants") Or TypeOf(Parameters.Variants) <> Type("Array") Then
		ErrorText = NStr("ru = 'Не указаны варианты отчетов.'; en = 'Report options are not specified.'; pl = 'Opcje sprawozdania nie zostały określone.';es_ES = 'Opciones del informe no especificadas.';es_CO = 'Opciones del informe no especificadas.';tr = 'Rapor seçenekleri belirtilmedi.';it = 'Le varianti di report non sono specificate.';de = 'Berichtsoptionen sind nicht angegeben.'");
		Return;
	EndIf;
	
	If Not HasUserSettings(Parameters.Variants) Then
		ErrorText = NStr("ru = 'Пользовательские настройки выбранных вариантов отчетов (%1 шт) не заданы или уже сброшены.'; en = 'User settings of the selected report options (%1 pcs.) were not specified or have already been reset.'; pl = 'Ustawienia użytkownika wybranych opcji sprawozdania (%1 szt.) nie zostały określone lub zostały już zresetowane.';es_ES = 'Configuraciones del usuario de las opciones del informe seleccionadas (%1 piezas) no se han especificado o ya se han restablecido.';es_CO = 'Configuraciones del usuario de las opciones del informe seleccionadas (%1 piezas) no se han especificado o ya se han restablecido.';tr = 'Seçilen rapor seçeneklerinin (%1 adet) kullanıcı ayarları belirtilmemiş veya zaten sıfırlanmış.';it = 'Impostazioni personalizzate delle varianti di report selezionate (%1 pz) non sono state specificate o sono già state reimpostate.';de = 'Benutzereinstellungen der ausgewählten Berichtsoptionen (%1 Stück) wurden nicht angegeben oder wurden bereits zurückgesetzt.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, Format(Parameters.Variants.Count(), "NZ=0; NG=0"));
		Return;
	EndIf;
	
	OptionsToAssign.LoadValues(Parameters.Variants);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IsBlankString(ErrorText) Then
		Cancel = True;
		ShowMessageBox(, ErrorText);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ResetCommand(Command)
	OptionsCount = OptionsToAssign.Count();
	If OptionsCount = 0 Then
		ShowMessageBox(, NStr("ru = 'Не указаны варианты отчетов.'; en = 'Report options are not specified.'; pl = 'Opcje sprawozdania nie zostały określone.';es_ES = 'Opciones del informe no especificadas.';es_CO = 'Opciones del informe no especificadas.';tr = 'Rapor seçenekleri belirtilmedi.';it = 'Le varianti di report non sono specificate.';de = 'Berichtsoptionen sind nicht angegeben.'"));
		Return;
	EndIf;
	
	ResetUserSettingsServer(OptionsToAssign);
	If OptionsCount = 1 Then
		OptionRef = OptionsToAssign[0].Value;
		NotificationTitle = NStr("ru = 'Сброшены пользовательские настройки варианта отчета'; en = 'User settings of report option were reset'; pl = 'Ustawienia użytkownika opcji sprawozdania zostały zresetowane';es_ES = 'Configuraciones del usuario de la opción del informe se han restablecido';es_CO = 'Configuraciones del usuario de la opción del informe se han restablecido';tr = 'Rapor seçeneğinin kullanıcı ayarları sıfırlandı';it = 'Le impostazioni utente della variante di report sono state reimpostate';de = 'Benutzereinstellungen der Berichtsoption wurden zurückgesetzt'");
		NotificationRef    = GetURL(OptionRef);
		NotificationText     = String(OptionRef);
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("ru = 'Сброшены пользовательские настройки
		|вариантов отчетов (%1 шт.).'; 
		|en = 'User settings
		|of report options were reset (%1 pcs.).'; 
		|pl = 'Niestandardowe ustawienia opcji
		|sprawozdania są resetowane (%1 szt.).';
		|es_ES = 'Los ajustes personalizadas
		|de las variantes del informe se han restablecido (%1 piezas).';
		|es_CO = 'Los ajustes personalizadas
		|de las variantes del informe se han restablecido (%1 piezas).';
		|tr = 'Rapor seçeneklerinin
		|kullanıcı ayarları sıfırlandı (%1 adet).';
		|it = 'Le impostazioni utente
		|delle opzioni di report sono state reimpostate (%1 pz).';
		|de = 'Die Benutzereinstellungen
		|für Berichtsoptionen (%1 Stk.) werden zurückgesetzt.'");
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NotificationText, Format(OptionsCount, "NZ=0; NG=0"));
		ShowUserNotification(, , NotificationText);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServerNoContext
Procedure ResetUserSettingsServer(Val OptionsToAssign)
	BeginTransaction();
	Try
		Lock = New DataLock;
		For Each ListItem In OptionsToAssign Do
			LockItem = Lock.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", ListItem.Value);
		EndDo;
		Lock.Lock();
		
		InformationRegisters.ReportOptionsSettings.ClearSettings(OptionsToAssign.UnloadValues());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function HasUserSettings(OptionsArray)
	Query = New Query;
	Query.SetParameter("OptionsArray", OptionsArray);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS HasUserSettings
	|FROM
	|	InformationRegister.ReportOptionsSettings AS Settings
	|WHERE
	|	Settings.Variant IN(&OptionsArray)";
	
	HasUserSettings = NOT Query.Execute().IsEmpty();
	Return HasUserSettings;
EndFunction

#EndRegion
