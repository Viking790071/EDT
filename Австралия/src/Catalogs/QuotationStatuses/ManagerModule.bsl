#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure SetPredefinedQuotationStatus() Export
	
	Reference = Catalogs.QuotationStatuses.Closed;
	
	If Not Reference.Disabled Then
		
		Object = Reference.GetObject();
		Object.Disabled = True;
		
		Try
			
			Object.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'"),
				Reference,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.QuotationStatuses,
				,
				ErrorDescription);
				
		EndTry;
		
	EndIf;
	
	Reference = Catalogs.QuotationStatuses.Converted;
	
	If Not Reference.Disabled Then
		
		Object = Reference.GetObject();
		Object.Disabled = True;
		
		Try
			
			Object.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Reference,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'Infobase update'; ru = 'Обновление информационной базы';pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualización de la infobase';es_CO = 'Actualización de la infobase';tr = 'Infobase güncellemesi';it = 'Aggiornamento del database';de = 'Infobase-Aktualisierung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.QuotationStatuses,
				,
				ErrorDescription);
				
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.QuotationStatuses);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure UpdateStatusConverted() Export
	
	ConvertedRef = Catalogs.QuotationStatuses.Converted;
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	QuotationStatuses.Ref AS Ref
	|FROM
	|	Catalog.QuotationStatuses AS QuotationStatuses
	|WHERE
	|	QuotationStatuses.Code = &Code
	|	AND NOT QuotationStatuses.Predefined";
	
	Query.SetParameter("Code", ConvertedRef.Code);
	
	QueryResult = Query.Execute();
	IsDouble = Not QueryResult.IsEmpty();
	
	If IsDouble Or Not ConvertedRef.Disabled Then
		
		ConvertedObject = ConvertedRef.GetObject();
		
		If Not ConvertedObject.Disabled Then
			ConvertedObject.Disabled = True;
		EndIf;
		
		If IsDouble Then
			ConvertedObject.SetNewCode();
		EndIf;
		
		Try
			InfobaseUpdate.WriteObject(ConvertedObject);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''anagrafica ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", DefaultLanguageCode),
				ConvertedRef,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(NStr("en = 'Infobase update'; ru = 'Обновление информационной базы';pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualización de la infobase';es_CO = 'Actualización de la infobase';tr = 'Infobase güncellemesi';it = 'Aggiornamento del database';de = 'Infobase-Aktualisierung'", DefaultLanguageCode),
				EventLogLevel.Error,
				Metadata.Catalogs.QuotationStatuses,
				,
				ErrorDescription);
			
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf