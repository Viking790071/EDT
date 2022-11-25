#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Details");
	Result.Add("Author");
	Result.Add("AvailableToAuthorOnly");
	
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	Custom = FALSE
	|	OR AvailableToAuthorOnly = FALSE
	|	OR IsAuthorizedUser(Author)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	IsAuthorizedUser(Author)";
	
	Restriction.TextForExternalUsers = Restriction.Text;
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
	// Overriding for favorites: the main form will be opened instead of the report placement settings 
	// card.
	If FormType = "ObjectForm" Then
		OptionRef = CommonClientServer.StructureProperty(Parameters, "Key");
		If Not ValueIsFilled(OptionRef) Then
			Raise NStr("ru = 'Новый вариант отчета можно создать только из формы отчета'; en = 'You can create report option only from the report form'; pl = 'Można utworzyć opcję sprawozdania tylko z formularza sprawozdania';es_ES = 'Usted puede crear la opción del informe solo desde el formulario de informes';es_CO = 'Usted puede crear la opción del informe solo desde el formulario de informes';tr = 'Rapor seçeneği yalnızca rapor formunda oluşturulabilir';it = 'Potete creare variante di report solo dal modulo di report';de = 'Sie können die Berichtsoption nur über das Berichtsformular erstellen'");
		EndIf;
		ShowCard = CommonClientServer.StructureProperty(Parameters, "ShowCard");
		If ShowCard = True Then
			Return;
		EndIf;
		
		OpeningParameters = ReportsOptions.OpeningParameters(OptionRef);
		
		ReportsOptionsClientServer.AddKeyToStructure(OpeningParameters, "RunMeasurements", False);
		
		If OpeningParameters.ReportType = "Internal" Or OpeningParameters.ReportType = "Extension" Then
			Kind = "Report";
		ElsIf OpeningParameters.ReportType = "Additional" Then
			Kind = "ExternalReport";
			If Not OpeningParameters.Property("Connected") Then
				ReportsOptions.OnAttachReport(OpeningParameters);
			EndIf;
			If Not OpeningParameters.Connected Then
				Raise NStr("ru = 'Вариант внешнего отчета можно открыть только из формы отчета.'; en = 'External report option can be opened only from the report form.'; pl = 'Opcja sprawozdania zewnętrznego może zostać otwarta tylko z formularza sprawozdania.';es_ES = 'Opción de un informe externo puede abrirse solo desde el formulario de informes.';es_CO = 'Opción de un informe externo puede abrirse solo desde el formulario de informes.';tr = 'Harici rapor seçeneği sadece rapor formundan açılabilir.';it = 'Una variante di report esterna può essere aperta solo dal  modulo report.';de = 'Die Option für den externen Bericht kann nur über das Berichtsformular geöffnet werden.'");
			EndIf;
		Else
			Raise NStr("ru = 'Вариант внешнего отчета можно открыть только из формы отчета.'; en = 'External report option can be opened only from the report form.'; pl = 'Opcja sprawozdania zewnętrznego może zostać otwarta tylko z formularza sprawozdania.';es_ES = 'Opción de un informe externo puede abrirse solo desde el formulario de informes.';es_CO = 'Opción de un informe externo puede abrirse solo desde el formulario de informes.';tr = 'Harici rapor seçeneği sadece rapor formundan açılabilir.';it = 'Una variante di report esterna può essere aperta solo dal  modulo report.';de = 'Die Option für den externen Bericht kann nur über das Berichtsformular geöffnet werden.'");
		EndIf;
		
		ReportFullName = Kind + "." + OpeningParameters.ReportName;
		
		UniqueKey = ReportsClientServer.UniqueKey(ReportFullName, OpeningParameters.VariantKey);
		OpeningParameters.Insert("PrintParametersKey",        UniqueKey);
		OpeningParameters.Insert("WindowOptionsKey", UniqueKey);
		
		StandardProcessing = False;
		If OpeningParameters.ReportType = "Additional" Then // For a platform.
			SelectedForm = "Catalog.ReportsOptions.Form.ItemForm";
			Parameters.Insert("ReportFormOpeningParameters", OpeningParameters);
			Return;
		EndIf;
		SelectedForm = ReportFullName + ".Form";
		CommonClientServer.SupplementStructure(Parameters, OpeningParameters);
	EndIf;
	
#EndIf
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers data for update in the InfobaseUpdate exchange plan. See Standards and methods of 
//  application development: Deferred update parallel mode. 
//
// Parameters:
//  Parameters - Structure - see InfobaseUpdate.MainProcessingMarkParameters. 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export 
	Query = New Query("
	|SELECT
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &UniversalReport
	|	AND Variants.Custom
	|");
	UniversalReport = Common.MetadataObjectID(Metadata.Reports.UniversalReport);
	Query.SetParameter("UniversalReport", UniversalReport);
	
	References = Query.Execute().Unload().UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, References);
EndProcedure

// Processes data registered in the InfobaseUpdate exchange plan. See Standards and methods of 
//  application development: Deferred update parallel mode. 
//
// Parameters:
//  Parameters - Structure - see InfobaseUpdate.MainProcessingMarkParameters. 
//
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export 
	MetadataObject = Metadata.Catalogs.ReportsOptions;
	FullObjectName = MetadataObject.FullName();
	
	Processed = 0;
	Declined = 0;
	
	Option = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, FullObjectName);
	While Option.Next() Do 
		Try
			Reports.UniversalReport.DetermineOptionDataSource(Option.Ref);
			Processed = Processed + 1;
		Except
			// If a report option could not be processed, try again.
			Declined = Declined + 1;
			
			CommentTemplate = NStr("ru = 'Не удалось установить источник данных варианта отчета %1.
				|Возможно он поврежден и не подлежит восстановлению.
				|
				|Техническая информация о проблеме: %2'; 
				|en = 'Cannot identify a data source of report option %1. 
				|It might be corrupted and cannot be restored.
				|
				|Technical details about the problem: %2'; 
				|pl = 'Nie udało się ustawić źródło danych wariantu sprawozdania %1.
				| Możliwe, że jest on uszkodzony i nie może być odzyskany. 
				|
				|Informacja techniczna o problemie: %2';
				|es_ES = 'No se ha podido determinar la fuente de los datos de la variante del informe %1.
				|Es posible que está dañada y no se pueda recuperarla.
				|
				|La información técnica del problema: %2';
				|es_CO = 'No se ha podido determinar la fuente de los datos de la variante del informe %1.
				|Es posible que está dañada y no se pueda recuperarla.
				|
				|La información técnica del problema: %2';
				|tr = '%1 rapor seçeneğinin veri kaynağı yüklenemedi. 
				|Bozuk ve düzeltilemiyor olabilir. 
				|
				|Sorun hakkında teknik bilgi: %2';
				|it = 'Impossibile identificare una fonte di dati dell''opzione di report %1. 
				|Potrebbe essere corrotta e non può essere ripristinata.
				|
				|Dettagli tecnici sul problema: %2';
				|de = 'In der Berichtsversion war es nicht möglich, die Quelle der Daten zu identifizieren %1.
				|Sie kann beschädigt werden und kann nicht wiederhergestellt werden.
				|
				|Technische Informationen zum Problem: %2'");
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				CommentTemplate, Option.Ref, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning,
				MetadataObject,
				Option.Ref,
				Comment);
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, FullObjectName);
	If Processed = 0 AND Declined <> 0 Then
		MessageTemplate = NStr("ru = 'Процедуре SetOptionDataSource не удалось обработать некоторые варианты отчетов: %1'; en = 'The SetOptionDataSource procedure cannot process some report options: %1'; pl = 'Procedurze SetOptionDataSource nie udało się przetworzyć niektórych wariantów sprawozdań: %1';es_ES = 'El procedimiento SetOptionDataSource no ha podido procesar algunas variantes de los informes: %1';es_CO = 'El procedimiento SetOptionDataSource no ha podido procesar algunas variantes de los informes: %1';tr = 'SetOptionDataSource prosedürü bazı rapor türlerini işleyemedi: %1';it = 'La procedura SetOptionDataSource non è riuscita ad elaborare alcune varianti dei report: %1';de = 'Das Verfahren SetOptionDataSource kann einige Berichtsoptionen nicht verarbeiten: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Declined);
		
		Raise MessageText;
	Else
		CommentTemplate = NStr("ru = 'Процедура SetOptionDataSource обработала очередной пакет вариантов отчетов: %1'; en = 'The SetOptionDataSource procedure has processed report option package: %1'; pl = 'Procedura SetOptionDataSource przetworzyła kolejny pakiet wariantów sprawozdań: %1';es_ES = 'El procedimiento SetOptionDataSource ha procesado un paquete de variantes de los informes: %1';es_CO = 'El procedimiento SetOptionDataSource ha procesado un paquete de variantes de los informes: %1';tr = 'SetOptionDataSource prosedürü sıradaki rapor seçenekleri paketini işledi: %1';it = 'La procedura SetOptionDataSource ha un pacchetto di opzioni di report elaborate: %1';de = 'Das Verfahren SetOptionDataSource hat das Paket der Berichtsoptionen verarbeitet: %1'");
		Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, Processed);
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			MetadataObject,,
			Comment);
	EndIf;
EndProcedure

#EndRegion

#EndIf