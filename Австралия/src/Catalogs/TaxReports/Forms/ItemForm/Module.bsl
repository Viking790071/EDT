
#Region FormEventHandlers
 
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.IsFilled Then
		
		Items.FormCreateReport.Title = NStr("en = 'Open report'; ru = 'Открыть отчет';pl = 'Otwórz raport';es_ES = 'Abrir el informe';es_CO = 'Abrir el informe';tr = 'Rapor aç';it = 'Aprire report';de = 'Bericht öffnen'");
		Items.SelectPeriod.Enabled = False;
		
		// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
		// End StandardSubsystems.ObjectAttributesLock
		
		OldCompany				= Object.Company;
		OldBeginOfPeriod		= Object.BeginOfPeriod;
		OldEndOfPeriod			= Object.EndOfPeriod;
		OldTaxReportTemplate	= Object.TaxReportTemplate;
		
	EndIf;

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Object.IsFilled Then
		// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
		// End StandardSubsystems.ObjectAttributesLock
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BeginOfPeriodOnChange(Item)
	
	If Not ValueIsFilled(Object.EndOfPeriod) Then
		Object.EndOfPeriod = EndOfMonth(Object.BeginOfPeriod);
	EndIf;
	
	If Object.IsFilled 
		And Not Object.BeginOfPeriod = OldBeginOfPeriod Then
		
		ShowQueryBox(New NotifyDescription("BeginOfPeriodOnChangeEnd", ThisObject),
			NStr("en = 'The report data will be cleared. Do you want to continue?'; ru = 'Данные отчета будут очищены. Продолжить?';pl = 'Dane raportu zostaną oczyszczone. Czy chcesz kontynuować?';es_ES = 'Los datos del informe se eliminarán. ¿Quiere continuar?';es_CO = 'Los datos del informe se eliminarán. ¿Quiere continuar?';tr = 'Rapor verileri temizlenecektir. Devam etmek istiyor musunuz?';it = 'I dati di report saranno cancellati. Continuare?';de = 'Die Berichtsdaten werden gelöscht. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.OKCancel,
			60);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeginOfPeriodOnChangeEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.OK Then
		
		ClearDataReport();
		Items.FormCreateReport.Title = NStr("en = 'Create report'; ru = 'Создать отчет';pl = 'Utwórz raport';es_ES = 'Generar informe';es_CO = 'Generar informe';tr = 'Rapor oluştur';it = 'Crea report';de = 'Bericht erstellen'");
		
	Else 
		Object.BeginOfPeriod = OldBeginOfPeriod;
	EndIf;

EndProcedure

&AtClient
Procedure EndOfPeriodOnChange(Item)
	
	If Object.IsFilled 
		And Not Object.BeginOfPeriod = OldBeginOfPeriod Then
		
		ShowQueryBox(New NotifyDescription("EndOfPeriodOnChangeEnd", ThisObject),
			NStr("en = 'The report data will be cleared. Do you want to continue?'; ru = 'Данные отчета будут очищены. Продолжить?';pl = 'Dane raportu zostaną oczyszczone. Czy chcesz kontynuować?';es_ES = 'Los datos del informe se eliminarán. ¿Quiere continuar?';es_CO = 'Los datos del informe se eliminarán. ¿Quiere continuar?';tr = 'Rapor verileri temizlenecektir. Devam etmek istiyor musunuz?';it = 'I dati di report saranno cancellati. Continuare?';de = 'Die Berichtsdaten werden gelöscht. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.OKCancel,
			60);
		
	EndIf;
		
EndProcedure

&AtClient
Procedure EndOfPeriodOnChangeEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.OK Then
		
		ClearDataReport();
		Items.FormCreateReport.Title = NStr("en = 'Create report'; ru = 'Создать отчет';pl = 'Utwórz raport';es_ES = 'Generar informe';es_CO = 'Generar informe';tr = 'Rapor oluştur';it = 'Crea report';de = 'Bericht erstellen'");
		
	Else 
		Object.EndOfPeriod = OldEndOfPeriod;
	EndIf;

EndProcedure

&AtClient
Procedure TaxReportTemplateOnChange(Item)
	
	TemplateDescription = GetTemplateDescription(Object.TaxReportTemplate);
	
	Object.Description	= TemplateDescription;
	
	If Object.IsFilled 
		And Not Object.TaxReportTemplate = OldTaxReportTemplate Then
		
		ShowQueryBox(New NotifyDescription("TaxReportTemplateOnChangeEnd", ThisObject),
			NStr("en = 'The report data will be cleared. Do you want to continue?'; ru = 'Данные отчета будут очищены. Продолжить?';pl = 'Dane raportu zostaną oczyszczone. Czy chcesz kontynuować?';es_ES = 'Los datos del informe se eliminarán. ¿Quiere continuar?';es_CO = 'Los datos del informe se eliminarán. ¿Quiere continuar?';tr = 'Rapor verileri temizlenecektir. Devam etmek istiyor musunuz?';it = 'I dati di report saranno cancellati. Continuare?';de = 'Die Berichtsdaten werden gelöscht. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.OKCancel,
			60);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxReportTemplateOnChangeEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.OK Then
		
		ClearDataReport();
		Items.FormCreateReport.Title = NStr("en = 'Create report'; ru = 'Создать отчет';pl = 'Utwórz raport';es_ES = 'Generar informe';es_CO = 'Generar informe';tr = 'Rapor oluştur';it = 'Creare report';de = 'Bericht erstellen'");
		
	Else 
		Object.TaxReportTemplate = OldTaxReportTemplate;
	EndIf;

EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If Object.IsFilled 
		And Not Object.Company = OldCompany Then
		
		ShowQueryBox(New NotifyDescription("CompanyOnChangeEnd", ThisObject),
			NStr("en = 'The report data will be cleared. Do you want to continue?'; ru = 'Данные отчета будут очищены. Продолжить?';pl = 'Dane raportu zostaną oczyszczone. Czy chcesz kontynuować?';es_ES = 'Los datos del informe se eliminarán. ¿Quiere continuar?';es_CO = 'Los datos del informe se eliminarán. ¿Quiere continuar?';tr = 'Rapor verileri temizlenecektir. Devam etmek istiyor musunuz?';it = 'I dati di report saranno cancellati. Continuare?';de = 'Die Berichtsdaten werden gelöscht. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.OKCancel,
			60);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChangeEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.OK Then
		
		ClearDataReport();
		Items.FormCreateReport.Title = NStr("en = 'Create report'; ru = 'Создать отчет';pl = 'Utwórz raport';es_ES = 'Generar informe';es_CO = 'Generar informe';tr = 'Rapor oluştur';it = 'Creare report';de = 'Bericht erstellen'");
		
	Else 
		Object.Company = OldCompany;
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectPeriod(Command)
	
	EditedPeriod = New StandardPeriod;
	EditedPeriod.StartDate = Object.BeginOfPeriod;
	EditedPeriod.EndDate = Object.EndOfPeriod;
	
	EditPeriodDialog = New StandardPeriodEditDialog;
	EditPeriodDialog.Period = EditedPeriod;
	EditPeriodHandler = New NotifyDescription("SelectPeriodProcessing", ThisObject);
	EditPeriodDialog.Show(EditPeriodHandler);
	
EndProcedure

&AtClient
Procedure SelectPeriodProcessing(NewPeriod, AdditionalParameters) Export
	
	If NewPeriod <> Undefined Then
		
		Object.BeginOfPeriod = NewPeriod.StartDate;
		Object.EndOfPeriod = NewPeriod.EndDate;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateReport(Command)
	
	If Not ValueIsFilled(Object.Company) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Company is required.'; ru = 'Поле ""Организация"" не заполнено.';pl = 'Wymagana jest firma.';es_ES = 'Se requiere la empresa.';es_CO = 'Se requiere la empresa.';tr = 'İş yeri gerekli.';it = 'E'' richiesta l''azienda.';de = 'Firma ist erforderlich.'"));
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(Object.BeginOfPeriod) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The period start date is required.'; ru = 'Требуется указать дату начала периода.';pl = 'Wymagany jest początek okresu.';es_ES = 'Se requiere la fecha de inicio del período.';es_CO = 'Se requiere la fecha de inicio del período.';tr = 'Dönem başlangıç tarihi gerekli.';it = 'È richiesta la data di inizio del periodo.';de = 'Das Startdatum des Zeitraums ist erforderlich.'"));
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(Object.EndOfPeriod) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The period end date is required.'; ru = 'Требуется указать дату конца периода.';pl = 'Wymagana jest data zakończenia okresu.';es_ES = 'Se requiere la fecha de finalización del período.';es_CO = 'Se requiere la fecha de finalización del período.';tr = 'Dönem sonu tarihi gerekli.';it = 'È richiesta la data di fine periodo.';de = 'Das Enddatum des Zeitraums ist erforderlich.'"));
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(Object.TaxReportTemplate) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The tax report template is required.'; ru = 'Требуется шаблон налогового отчета.';pl = 'Wymagany jest szablon raportu podatkowego.';es_ES = 'Se requiere el modelo de informe de impuesto.';es_CO = 'Se requiere el modelo de informe de impuesto.';tr = 'Vergi raporu şablonu gerekli.';it = 'È richiesto il modello di report fiscale.';de = 'Die Steuerberichtsvorlage ist erforderlich.'"));
		Return;
		
	EndIf;
	
	If Object.Ref.IsEmpty() 
		And Not WriteObject() Then
		
		Return;
		
	EndIf;
	
	
		
	ParametersOfDataProcessor = New Structure();
	ParametersOfDataProcessor.Insert("Company",Object.Company);
	ParametersOfDataProcessor.Insert("BeginOfPeriod",Object.BeginOfPeriod);
	ParametersOfDataProcessor.Insert("EndOfPeriod",Object.EndOfPeriod);
	ParametersOfDataProcessor.Insert("ReferenceTaxReport",Object.Ref);
	ParametersOfDataProcessor.Insert("IsFilled", Object.IsFilled);
	ParametersOfDataProcessor.Insert("ReportStatus", Object.ReportStatus);
	
	Cancel = False;
	
	NameDataProcessor = ConnectExternalDataProcessor(ParametersOfDataProcessor, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
	OpenForm("ExternalDataProcessor." + NameDataProcessor + ".Form",
		ParametersOfDataProcessor,
		ThisObject,
		,,,,
		FormWindowOpeningMode.Independent);
		
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetTemplateDescription(TaxReportTemplate)
	
	Return Common.ObjectAttributeValue(TaxReportTemplate, "Description");
	
EndFunction

&AtServer
Function WriteObject()
	
	TemplateDescription = Common.ObjectAttributeValue(Object.TaxReportTemplate, "Description");
	
	CompanyDescription = Common.ObjectAttributeValue(Object.Company, "Description");
	
	PeriodDescription = Format(Object.BeginOfPeriod, "DLF=D") + " - " + Format(Object.BeginOfPeriod, "DLF=D");
	
	StringDescription = TemplateDescription + " "+CompanyDescription+" "+PeriodDescription;
	
	If TrimAll(Object.Comment) = "" Then
		Object.Comment		= StringDescription;
	EndIf;
	
	ObjectTaxReport = FormAttributeToValue("Object");
	
	Try
	
		ObjectTaxReport.Write(); 
		ValueToFormAttribute(ObjectTaxReport,"Object");
		Return True;
		
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Object.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'WriteTaxReport'; ru = 'WriteTaxReport';pl = 'WriteTaxReport';es_ES = 'WriteTaxReport';es_CO = 'WriteTaxReport';tr = 'WriteTaxReport';it = 'WriteTaxReport';de = 'WriteTaxReport'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.TaxReports,
				,
				ErrorDescription);
				
		Return False;
	
	EndTry;
	
	
	
EndFunction

&AtServer
Procedure ClearDataReport()
	
	ObjectTaxReport = FormAttributeToValue("Object");
	
	ObjectTaxReport.IsFilled			= False;
	ObjectTaxReport.TaxReportStorage	= Undefined;
	
	Try
	
		ObjectTaxReport.Write();
		ValueToFormAttribute(ObjectTaxReport,"Object");
	
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
			Object.Ref,
			BriefErrorDescription(ErrorInfo()));
				
		WriteLogEvent(
			NStr("en = 'WriteTaxReport'; ru = 'WriteTaxReport';pl = 'WriteTaxReport';es_ES = 'WriteTaxReport';es_CO = 'WriteTaxReport';tr = 'WriteTaxReport';it = 'WriteTaxReport';de = 'WriteTaxReport'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.TaxReports,
			,
			ErrorDescription);
				
	EndTry;

EndProcedure

&AtServerNoContext
Function ConnectExternalDataProcessor(ParametersOfDataProcessor, Cancel)
	
	NameDataProcessor = Catalogs.TaxReports.GetExternalDataProcessor(ParametersOfDataProcessor, Cancel);
	
	Return NameDataProcessor;
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ContinuationHandler = New NotifyDescription("AllowObjectAttributesEditingEnd", ThisObject);
	
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject, ContinuationHandler);
	
EndProcedure


&AtClient
Procedure AllowObjectAttributesEditingEnd(UnlockAttributes, Context) Export
	
	If UnlockAttributes Then
		Items.SelectPeriod.Enabled = True;
	EndIf;
	
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

&AtClient
Procedure FormManagement()
	
	If Object.ReportStatus = PredefinedValue("Enum.TaxReportStatuses.Sent")
		And Object.IsFilled Then
		
		Items.AllowObjectAttributeEdit.Enabled = False;
		Items.ReportStatus.Enabled = False;
		
	EndIf;
	
EndProcedure

#EndRegion
