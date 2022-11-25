
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
	
	OptionsToAssign.LoadValues(Parameters.Variants);
	Filter();
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
	NumberOfSelectedOptions = OptionsToAssign.Count();
	If NumberOfSelectedOptions = 0 Then
		ShowMessageBox(, NStr("ru = 'Не указаны варианты отчетов.'; en = 'Report options are not specified.'; pl = 'Opcje sprawozdania nie zostały określone.';es_ES = 'Opciones del informe no especificadas.';es_CO = 'Opciones del informe no especificadas.';tr = 'Rapor seçenekleri belirtilmedi.';it = 'Le varianti di report non sono specificate.';de = 'Berichtsoptionen sind nicht angegeben.'"));
		Return;
	EndIf;
	
	OptionsCount = ResetAssignmentSettingsServer(OptionsToAssign);
	If OptionsCount = 1 AND NumberOfSelectedOptions = 1 Then
		OptionRef = OptionsToAssign[0].Value;
		NotificationTitle = NStr("ru = 'Сброшены настройки размещения варианта отчета'; en = 'Placement settings of report option were reset'; pl = 'Ustawienia ulokowania opcji sprawozdania zostały zresetowane';es_ES = 'Configuraciones de colocación de la opción del informe se han restablecido';es_CO = 'Configuraciones de colocación de la opción del informe se han restablecido';tr = 'Rapor seçeneğinin yerleştirme ayarları sıfırlandı';it = 'Le impostazioni di localizzazione della variante di report sono state reimpostate';de = 'Die Placement-Einstellungen der Berichtsoption wurden zurückgesetzt'");
		NotificationRef    = GetURL(OptionRef);
		NotificationText     = String(OptionRef);
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("ru = 'Сброшены настройки размещения
		|вариантов отчетов (%1 шт.).'; 
		|en = 'Placement settings of report
		|options were reset (%1 pcs).'; 
		|pl = 'Zresetowano ustawienia rozmieszczania
		|wariantów raportów (%1 szt.).';
		|es_ES = 'Los ajustes para la colocación de
		|las variantes del informe se han restablecido (%1 piezas).';
		|es_CO = 'Los ajustes para la colocación de
		|las variantes del informe se han restablecido (%1 piezas).';
		|tr = 'Rapor 
		|seçenekleri yerleştirme ayarları sıfırlandı (%1 adet).';
		|it = 'Le impostazioni di posizionamento delle opzioni
		|di report sono state reimpostate (%1 pz).';
		|de = 'Setzen Sie die Einstellungen für die Platzierung
		|von Berichtsvarianten (%1 Stk.) zurück.'");
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NotificationText, Format(OptionsCount, "NZ=0; NG=0"));
		ShowUserNotification(, , NotificationText);
	EndIf;
	ReportsOptionsClient.UpdateOpenForms();
	Close();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServerNoContext
Function ResetAssignmentSettingsServer(Val OptionsToAssign)
	OptionsCount = 0;
	BeginTransaction();
	Try
		Lock = New DataLock;
		For Each ListItem In OptionsToAssign Do
			LockItem = Lock.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", ListItem.Value);
		EndDo;
		Lock.Lock();
		
		For Each ListItem In OptionsToAssign Do
			OptionObject = ListItem.Value.GetObject();
			If ReportsOptions.ResetReportOptionSettings(OptionObject) Then
				OptionObject.Write();
				OptionsCount = OptionsCount + 1;
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	Return OptionsCount;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure Filter()
	
	CountBeforeFilter = OptionsToAssign.Count();
	
	Query = New Query;
	Query.SetParameter("OptionsArray", OptionsToAssign.UnloadValues());
	Query.SetParameter("InternalType", Enums.ReportTypes.Internal);
	Query.SetParameter("ExtensionType", Enums.ReportTypes.Extension);
	Query.Text =
	"SELECT DISTINCT
	|	ReportOptionsPlacement.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportOptionsPlacement
	|WHERE
	|	ReportOptionsPlacement.Ref IN(&OptionsArray)
	|	AND ReportOptionsPlacement.Custom = FALSE
	|	AND ReportOptionsPlacement.ReportType IN (&InternalType, &ExtensionType)
	|	AND ReportOptionsPlacement.DeletionMark = FALSE";
	
	OptionsArray = Query.Execute().Unload().UnloadColumn("Ref");
	OptionsToAssign.LoadValues(OptionsArray);
	
	CountAfterFilter = OptionsToAssign.Count();
	If CountBeforeFilter <> CountAfterFilter Then
		If CountAfterFilter = 0 Then
			ErrorText = NStr("ru = 'Сброс настроек размещения выбранных вариантов отчетов не требуется по одной или нескольким причинам:
			|- Выбраны пользовательские варианты отчетов.
			|- Выбраны помеченные на удаление варианты отчетов.
			|- Выбраны варианты дополнительных или внешних отчетов.'; 
			|en = 'No need to reset placement settings of the selected report options due to one/more of the following reasons:
			|- User report options selected.
			|- Report options marked for deletion selected.
			|- Options of additional or external reports selected.'; 
			|pl = 'Resetowanie ustawień rozmieszczania wybranych wariantów raportów nie jest konieczne z jednego lub kilku powodów:
			|- Wybrano niestandardowe warianty raportów.
			|- Wybrano zaznaczone do usunięcia warianty raportów.
			|- Wybrano warianty dodatkowych raportów lub raportów zewnętrznych.';
			|es_ES = 'No es necesario restablecer los ajustes de las variantes de informes seleccionadas por un o varios motivos:
			|- Variantes de informes personalizadas se han seleccionado.
			|- Variantes de informes marcadas para borrar se han seleccionado.
			| - Variantes de informes adicionales o externas se han seleccionado.';
			|es_CO = 'No es necesario restablecer los ajustes de las variantes de informes seleccionadas por un o varios motivos:
			|- Variantes de informes personalizadas se han seleccionado.
			|- Variantes de informes marcadas para borrar se han seleccionado.
			| - Variantes de informes adicionales o externas se han seleccionado.';
			|tr = 'Seçilen rapor seçeneklerinin ayarlarının sıfırlanması bir veya 
			|birkaç nedenden dolayı gerekmemektedir:- Özel rapor seçenekleri seçildi. 
			|- Silinmek üzere işaretlenmiş raporlama seçenekleri seçildi.
			|- Ek veya harici raporlar seçenekleri seçildi.';
			|it = 'Non vi è necessità di reimpostare le impostazioni di collocamento delle opzioni di report selezionate a causa di uno/più dei seguenti motivi:
			|- Opzioni di report utente selezionate.
			|- Opzioni di report contrassegnate per la cancellazione selezionate.
			|- Opzioni di report esterni o aggiuntivi selezionate.';
			|de = 'Ein Zurücksetzen der Platzierung der ausgewählten Berichtsoptionen ist aus einem oder mehreren Gründen nicht erforderlich:
			|- Benutzerdefinierte Berichtsoptionen wurden ausgewählt.
			|- Die zum Löschen markierten Berichtsoptionen sind ausgewählt.
			|- Die Optionen für zusätzliche oder externe Berichte sind ausgewählt.'");
			Return;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
