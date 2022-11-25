#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillPredefinedDataProperties() Export 
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IncomeAndExpenseItems.Ref AS Ref
	|FROM
	|	Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|WHERE
	|	IncomeAndExpenseItems.Ref = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
	|	AND IncomeAndExpenseItems.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	If Not Selection.Next() Then
		Return;
	EndIf;
	
	Object = Selection.Ref.GetObject();
	If Object = Undefined Then
		Return;
	EndIf;
	
	Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherIncomeExpenses;
	Object.MethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute;
	
	Try
		
		InfobaseUpdate.WriteObject(Object);
		
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t save an item to catalog ""Income and expense items"". Details : %1.'; ru = 'Не удалось записать элемент в справочник ""Статьи доходов и расходов"". Подробности: %1.';pl = 'Nie udało się zapisać elementu do katalogu ""Pozycje dochodów i rozchodów"". Szczegóły: %1.';es_ES = 'No se ha podido guardar un artículo en el catálogo ""Artículos de ingresos y gastos"". Detalles : %1.';es_CO = 'No se ha podido guardar un artículo en el catálogo ""Artículos de ingresos y gastos"". Detalles : %1.';tr = '""Gelir ve gider kalemleri"" kataloğuna öğe kaydedilemedi. Ayrıntılar: %1.';it = 'Impossibile salvare un elemento nel catalogo ""Voci di entrata e uscita"". Dettagli: %1.';de = 'Fehler beim Speichern eines Elements im Katalog ""Positionen von Einnahmen und Ausgaben"". Details : %1.'"),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,
			Metadata.Catalogs.IncomeAndExpenseTypes,
			,
			ErrorDescription);
		
	EndTry;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.IncomeAndExpenseItems);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
 	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf