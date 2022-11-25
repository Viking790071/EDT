#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.PlanningPeriods);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Internal

#Region InfobaseUpdate

Procedure FillRequiredAttributes() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PlanningPeriods.Ref AS Ref
	|FROM
	|	Catalog.PlanningPeriods AS PlanningPeriods
	|WHERE
	|	PlanningPeriods.Ref = VALUE(Catalog.PlanningPeriods.Actual)
	|	AND PlanningPeriods.Periodicity = VALUE(Enum.Periodicity.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do 
		
		PlanningPeriod = Selection.Ref.GetObject();
		If PlanningPeriod = Undefined Then
			Continue;
		EndIf;
		
		PlanningPeriod.Periodicity = Enums.Periodicity.Month;
		
		Try 
			InfobaseUpdate.WriteObject(PlanningPeriod);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t save catalog item ""%1"". Details: %2.'; ru = 'Не удалось записать элемент ""%1"". Подробнее: %2.';pl = 'Nie udało się zapisać elementu katalogu ""%1"". Szczegóły: %2.';es_ES = 'No se ha podido guardar el artículo del catálogo ""%1"". Detalles: %2.';es_CO = 'No se ha podido guardar el artículo del catálogo ""%1"". Detalles: %2.';tr = '""%1"" katalog öğesi saklanamadı. Ayrıntılar: %2.';it = 'Impossibile salvare l''elemento ""%1"" del catalogo. Dettagli: %2.';de = 'Fehler beim Speichern der Katalogposition ""%1"". Details: %2.'", DefaultLanguageCode),
				PlanningPeriod,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.PlanningPeriods,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion 

#EndRegion 

#EndIf