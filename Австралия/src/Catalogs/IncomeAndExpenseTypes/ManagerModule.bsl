#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function FillIsIncomeExpense(IncomeAndExpenseType) Export
	
	Structure = New Structure("IsIncome, IsExpense", False, False);
	
	Category = Common.ObjectAttributeValue(IncomeAndExpenseType, "IncomeAndExpenseCategory");
	
	Structure.IsIncome = (Category <> Enums.IncomeAndExpenseCategories.Expense);
	Structure.IsExpense = (Category <> Enums.IncomeAndExpenseCategories.Income);
	
	Return Structure;
	
EndFunction

Procedure FillPredefinedDataProperties() Export 
	
	BeginTransaction();
	
	Try
		
		Object = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.Expense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.CostOfSales.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.Expense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.Expense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.OtherExpenses.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.Expense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.OtherIncome.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.Income;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.OtherIncomeExpenses.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.IncomeExpense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.PurchaseReturn.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.IncomeExpense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.Revenue.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.IncomeExpense;
		InfobaseUpdate.WriteObject(Object);
		
		Object = Catalogs.IncomeAndExpenseTypes.SalesReturn.GetObject();
		Object.IncomeAndExpenseCategory = Enums.IncomeAndExpenseCategories.IncomeExpense;
		InfobaseUpdate.WriteObject(Object);
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t save an item to catalog ""Income and expense types"". Details : %1.'; ru = 'Не удалось записать элемент в справочник ""Типы доходов и расходов"". Подробности: %1.';pl = 'Nie udało się zapisać elementu do katalogu ""Typy dochodów i rozchodów"". Szczegóły: %1.';es_ES = 'No se ha podido guardar un artículo en el catálogo ""Tipos de ingresos y gastos"". Detalles : %1.';es_CO = 'No se ha podido guardar un artículo en el catálogo ""Tipos de ingresos y gastos"". Detalles : %1.';tr = '""Gelir ve gider türleri"" kataloğuna öğe kaydedilemedi. Ayrıntılar: %1.';it = 'Impossibile salvare un elemento nel catalogo ""Tipi di entrata e uscita"". Dettagli: %1.';de = 'Fehler beim Speichern einer Position im Katalog ""Typen von Einnahme und Ausgaben"". Details : %1.'"),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,
			Metadata.Catalogs.IncomeAndExpenseTypes,
			,
			ErrorDescription);
		
	EndTry;
	
	CommitTransaction();
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.IncomeAndExpenseTypes);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf