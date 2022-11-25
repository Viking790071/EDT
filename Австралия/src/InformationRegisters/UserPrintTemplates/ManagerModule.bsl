#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Registers the objects to be updated to the latest version in the InfobaseUpdate exchange plan.
// 
//
// Parameters:
//  Parameters - Structure - an internal parameter to pass to the InfobaseUpdate.MarkForProcessing procedure.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText =
	"SELECT
	|	UserPrintTemplates.TemplateName AS TemplateName,
	|	UserPrintTemplates.Object AS Object
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates";
	
	Query = New Query(QueryText);
	UserTemplates = Query.Execute().Unload();
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName = "InformationRegister.UserPrintTemplates";
	
	InfobaseUpdate.MarkForProcessing(Parameters, UserTemplates, AdditionalParameters);
	
EndProcedure

Procedure ProcessUserTemplates(Parameters) Export
	
	TemplatesInDOCXFormat = New Array;
	SSLSubsystemsIntegration.OnPrepareTemplateListInOfficeDocumentServerFormat(TemplatesInDOCXFormat);
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.PositionInQueue, "InformationRegister.UserPrintTemplates");
		
	While Selection.Next() Do
		Record = CreateRecordManager();
		Record.TemplateName = Selection.TemplateName;
		Record.Object = Selection.Object;
		Record.Read();
		ModifiedTemplate = Record.Template.Get();
		
		IsCommonTemplate = StrSplit(Selection.Object, ".", True).Count() < 2;
		
		If IsCommonTemplate Then
			TemplateMetadataObjectName = "CommonTemplate." + Selection.TemplateName;
		Else
			TemplateMetadataObjectName = Selection.Object + ".Template." + Selection.TemplateName;
		EndIf;
		
		FullTemplateName = Selection.Object + "." + Selection.TemplateName;
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.Object);
		RecordSet.Filter.TemplateName.Set(Selection.TemplateName);
		
		If Metadata.FindByFullName(TemplateMetadataObjectName) = Undefined Then
			EventName = NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'", CommonClientServer.DefaultLanguageCode());
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Обнаружен пользовательский макет, отсутствующий в метаданных конфигурации:
					|""%1"".'; 
					|en = 'User template, which is missing in configuration metadata, is found:
					|""%1"".'; 
					|pl = 'Znaleziono niestandardowy układ, którego nie ma w metadanych konfiguracji: 
					|""%1"".';
					|es_ES = 'Se ha encontrado una plantilla de usuario que no se encuentra en los metadatos de la configuración:
					|""%1"".';
					|es_CO = 'Se ha encontrado una plantilla de usuario que no se encuentra en los metadatos de la configuración:
					|""%1"".';
					|tr = 'Aşağıdaki yapılandırmadaki metaverilerde bulunmayan kullanıcı şablonu tespit edilmiştir: 
					|""%1"".';
					|it = 'Trovato il modello utente, che manca nei metadati di configurazione:
					|""%1"".';
					|de = 'Es wurde ein benutzerdefiniertes Layout erkannt, das in den Konfigurationsmetadaten nicht vorhanden ist:
					|""%1"".'"), TemplateMetadataObjectName);
			WriteLogEvent(EventName, EventLogLevel.Warning, , TemplateMetadataObjectName, ErrorText);
			InfobaseUpdate.MarkProcessingCompletion(RecordSet);
			Continue;
		EndIf;
		
		If IsCommonTemplate Then
			TemplateFromMetadata = GetCommonTemplate(Selection.TemplateName);
		Else
			TemplateFromMetadata = Common.ObjectManagerByFullName(Selection.Object).GetTemplate(Selection.TemplateName);
		EndIf;
		
		If Not PrintManagement.TemplatesDiffer(TemplateFromMetadata, ModifiedTemplate) Then
			InfobaseUpdate.WriteData(RecordSet);
		ElsIf TemplatesInDOCXFormat.Find(FullTemplateName) <> Undefined
			AND TypeOf(TemplateFromMetadata) = Type("BinaryData") AND TypeOf(ModifiedTemplate) = Type("BinaryData")
			AND OfficeDocumentsTemplatesTypesDiffer(TemplateFromMetadata, ModifiedTemplate) Then
			PrintManagement.DisableUserTemplate(FullTemplateName);
		Else
			InfobaseUpdate.MarkProcessingCompletion(RecordSet);
		EndIf;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "InformationRegister.UserPrintTemplates");
	
EndProcedure

#EndRegion

#Region Private

Function OfficeDocumentsTemplatesTypesDiffer(InitialTemplate, ModifiedTemplate)
	
	Return PrintManagementInternal.DefineDataFileExtensionBySignature(InitialTemplate) <> PrintManagementInternal.DefineDataFileExtensionBySignature(ModifiedTemplate);
	
EndFunction

#EndRegion

#EndIf
