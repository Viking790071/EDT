#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure PutContainer(Container, ReferenceTaxReport) Export
	
	ObjectTaxReport = ReferenceTaxReport.GetObject();
	
	If ObjectTaxReport.ReportStatus = Enums.TaxReportStatuses.Sent Then
		
		Container.Insert("UnableSave", True);
		
		Return;
		
	EndIf;
		
	If Container.Property("ReportStatus") Then
		ObjectTaxReport.ReportStatus = Container.ReportStatus;
		Container.Delete("ReportStatus");
	EndIf;
	
	ObjectTaxReport.TaxReportStorage = New ValueStorage(Container, New Deflation(9));
	ObjectTaxReport.IsFilled = True;
	
	Try
	
		ObjectTaxReport.Write();
	
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				ReferenceTaxReport,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'WriteTaxReport'; ru = 'WriteTaxReport';pl = 'WriteTaxReport';es_ES = 'WriteTaxReport';es_CO = 'WriteTaxReport';tr = 'WriteTaxReport';it = 'WriteTaxReport';de = 'WriteTaxReport'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.TaxReports,
				,
				ErrorDescription);
	
	EndTry;
	
EndProcedure

Function GetContainer(ReferenceTaxReport) Export
	
	TaxReportStorage = Common.ObjectAttributeValue(ReferenceTaxReport, "TaxReportStorage");
	
	Container = TaxReportStorage.Get();
	
	Return Container;
	
EndFunction

Function GetExternalDataProcessor(ParametersOfDataProcessor, Cancel) Export
	
	NameDataProcessor = ConnectExternalDataProcessor(ParametersOfDataProcessor.ReferenceTaxReport);
	
	ExternalObject = ExternalDataProcessors.Create(NameDataProcessor);
	
	ExternalObject.CheckingParameters(ParametersOfDataProcessor, Cancel);
	
	Return NameDataProcessor;
	
EndFunction

Function ConnectExternalDataProcessor(RefTaxReport) Export
	
	TaxReportTemplate = Common.ObjectAttributeValue(RefTaxReport, "TaxReportTemplate");
	
	TemplateStorage = Common.ObjectAttributeValue(TaxReportTemplate, "TemplateStorage");
	
	StringTemporaryStorageAddress = PutToTempStorage(TemplateStorage.Get());
	
	If Common.HasUnsafeActionProtection() Then
		NameDataProcessor = TrimAll(ExternalDataProcessors.Connect(StringTemporaryStorageAddress, , False,
		Common.ProtectionWithoutWarningsDetails()));
	Else
		NameDataProcessor = TrimAll(ExternalDataProcessors.Connect(StringTemporaryStorageAddress, , False));
	EndIf;
	
	Return NameDataProcessor;
	
EndFunction

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	AttributesToLock.Add("BeginOfPeriod");
	AttributesToLock.Add("EndOfPeriod");
	AttributesToLock.Add("Company");
	AttributesToLock.Add("TaxReportTemplate");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndIf