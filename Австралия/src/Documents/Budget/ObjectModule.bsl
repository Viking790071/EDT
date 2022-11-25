#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each LineIncome In Incomings Do
			
			If LineIncome.IncomeItem = Catalogs.IncomeAndExpenseTypes.OtherIncome Then
				LineIncome.BusinessLine = Catalogs.LinesOfBusiness.Other;
			Else
				LineIncome.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
			
		EndDo;
		
		For Each LineExpense In Expenses Do
			
			ExpenseItemType = Common.ObjectAttributeValue(LineExpense.ExpenseItem, "IncomeAndExpenseType");
			
			If ExpenseItemType = Catalogs.IncomeAndExpenseTypes.OtherExpenses 
				Or ExpenseItemType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then 
				LineExpense.BusinessLine = Catalogs.LinesOfBusiness.Other;
			Else
				LineExpense.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	StructureAdditionalProperties.ForPosting.Insert("PlanningPeriod", PlanningPeriod);
	StructureAdditionalProperties.ForPosting.Insert("Periodicity", PlanningPeriod.Periodicity);
	StructureAdditionalProperties.ForPosting.Insert("StartDate", PlanningPeriod.StartDate);
	StructureAdditionalProperties.ForPosting.Insert("EndDate", PlanningPeriod.EndDate);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each LineIncome In Incomings Do
		
		IncomeItemType = Common.ObjectAttributeValue(LineIncome.IncomeItem, "IncomeAndExpenseType");
		
		If IncomeItemType = Catalogs.IncomeAndExpenseTypes.Revenue Then
			
			If Not ValueIsFilled(LineIncome.StructuralUnit) Then
				
				TextError = NStr("en = 'Department is not indicated on string. 
					|Fillings is required for basic activity incomings.'; 
					|ru = 'В строке не указано подразделение. 
					|Для получения доходов по основному виду деятельности требуется заполнение.';
					|pl = 'Dział nie jest podany w wierszu. 
					|Wymagane jest wypełnianie dla przychodów z podstawowej działalności.';
					|es_ES = 'En la línea no está indicado el departamento. 
					|Se debe rellenar para obtener los ingresos de la actividad básica.';
					|es_CO = 'En la línea no está indicado el departamento. 
					|Se debe rellenar para obtener los ingresos de la actividad básica.';
					|tr = 'Dizede bölüm belirtilmedi. 
					|Temel faaliyet gelirleri için doldurması zorunludur.';
					|it = 'Il reparto non è indicato nella stringa. 
					|Sono richieste le compilazioni per le entrate di attività di base.';
					|de = 'Abteilung ist in der Zeichenfolge nicht angegeben. 
					|Füllungen sind erforderlich für grundlegende Aktivitätseinnahmen.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"Incomings",
					LineIncome.LineNumber,
					"StructuralUnit",
					Cancel);
				
			EndIf;
			
		EndIf;
		
		If IncomeItemType = Catalogs.IncomeAndExpenseTypes.OtherIncome Then
			
			If ValueIsFilled(LineIncome.BusinessLine) AND (LineIncome.BusinessLine <> Catalogs.LinesOfBusiness.Other) Then
				
				TextError = NStr("en = 'The type of activity specified in the row differs from ''Other''. 
					|For other income, it is necessary to specify the other type of activity.'; 
					|ru = 'Указанный в строке тип деятельности отличается от ''Прочие''. 
					|Для прочего дохода необходимо указать другой тип деятельности.';
					|pl = 'Typ rodzaju działalności wybrany w wierszu różni się od ''Inne''. 
					|Dla innych dochodów, konieczne jest określenie innego typu rodzaju działalności.';
					|es_ES = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros ingresos, es necesario especificar otro tipo de actividad.';
					|es_CO = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros ingresos, es necesario especificar otro tipo de actividad.';
					|tr = 'Satırda belirtilen faaliyet türü ""Diğer""den farklı. 
					|Diğer gelirler için diğer faaliyet türü belirtilmelidir.';
					|it = 'Il tipo di attività specificato nella riga è diverso da ''Altro''. 
					|Per altri ricavi è necessario specificare l''altro tipo di attività.';
					|de = 'Der in der Zeile angegebene Aktivitätstyp unterscheidet sich von ''Anderes''. 
					|Für sonstige Einnahmen ist es notwendig, den anderen Aktivitätstyp anzugeben.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"Incomings",
					LineIncome.LineNumber,
					"BusinessLine",
					Cancel);
				
			EndIf;
			
			If ValueIsFilled(LineIncome.StructuralUnit) Then
				
				TextError = NStr("en = 'Department is indicated on string. 
					|For the income from other types of business activity, filling is not required.'; 
					|ru = 'В строке указано подразделение. 
					|Для получения доходов от других типов предпринимательской деятельности заполнение не требуется.';
					|pl = 'Dzieł jest podany w wierszu. 
					|Dla przychodów od innych rodzajów działalności biznesowej, wypełnianie nie jest wymagane.';
					|es_ES = 'El departamento está indicado en la línea.
					|No es necesario rellenar para los ingresos de otros tipos de actividad comercial.';
					|es_CO = 'El departamento está indicado en la línea.
					|No es necesario rellenar para los ingresos de otros tipos de actividad comercial.';
					|tr = 'Dizede bölüm belirtildi. 
					|Diğer iş faaliyeti türlerinden elde edilen gelirler için doldurulması zorunlu değildir.';
					|it = 'Il reparto è indicato nella stringa. 
					|Per il ricavo da altri tipi di attività aziendale, non è richiesta la compilazione.';
					|de = 'Abteilung ist auf Zeichenfolge angegeben. 
					|Für die Einnahmen aus anderen Geschäftstätigkeiten ist keine Füllung erforderlich.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"Incomings",
					LineIncome.LineNumber,
					"StructuralUnit",
					Cancel);
				
			EndIf;
			
		EndIf;
	
	EndDo;
	
	For Each LineExpense In Expenses Do
		
		ExpenseItemType = Common.ObjectAttributeValue(LineExpense.ExpenseItem, "IncomeAndExpenseType");
		
		If ExpenseItemType = Catalogs.IncomeAndExpenseTypes.OtherExpenses 
			Or ExpenseItemType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
			
			If Not ValueIsFilled(LineExpense.BusinessLine) Then
				
				TextError = NStr("en = 'Activity direction is indicated on string.'; ru = 'Направление деятельности указано в строке.';pl = 'Rodzaj działalności jest podany w wierszu.';es_ES = 'La dirección de la actividad se ha indicado en la línea.';es_CO = 'La dirección de la actividad se ha indicado en la línea.';tr = 'Dizede faaliyet yönü belirtildi.';it = 'La direzione dell''attività è indicata sulla stringa.';de = 'Die Aktivitätsrichtung wird in der Zeichenfolge angezeigt.'");
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					TextError,
					"Expenses",
					LineExpense.LineNumber,
					"BusinessLine",
					Cancel);
				
			EndIf;
			
			If ValueIsFilled(LineExpense.BusinessLine) AND (LineExpense.BusinessLine <> Catalogs.LinesOfBusiness.Other) Then
				
				TextError = NStr("en = 'The type of activity specified in the row differs from ''Other''. 
					|For other expenses, it is necessary to specify the other type of activity.'; 
					|ru = 'Указанный в строке тип деятельности отличается от ''Прочие''. 
					|Для прочих расходов необходимо указать другой тип деятельности.';
					|pl = 'Podany rodzaj działalności określony różni się od ''Inne''. 
					|Dla innych wydatków należy podać inny rodzaj działalności.';
					|es_ES = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros gastos, es necesario especificar otro tipo de actividad.';
					|es_CO = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros gastos, es necesario especificar otro tipo de actividad.';
					|tr = 'Satırda belirtilen faaliyet türü ""Diğer""den farklı. 
					|Diğer masraflar için diğer faaliyet türü belirtilmelidir.';
					|it = 'Il tipo di attività specificato nella riga è diverso da ''Altro''. 
					|Per altre spese è necessario specificare l''altro tipo di attività.';
					|de = 'Der in der Zeile angegebene Aktivitätstyp unterscheidet sich von ''Anderes''. 
					|Für sonstige Ausgaben ist es notwendig, den anderen Aktivitätstyp anzugeben.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					"The type of activity specified in the row differs from 'Other'. For other expenses, it is necessary to specify the other type of activity.",
					"Expenses",
					LineExpense.LineNumber,
					"BusinessLine",
					Cancel);
				
			EndIf;
			
			If ValueIsFilled(LineExpense.StructuralUnit) Then
				
				TextError = NStr("en = 'Department is indicated on string. 
					|For expenses on other type of activities, filling is not required.'; 
					|ru = 'В строке указано подразделение. 
					|Для получения доходов от других типов деятельности заполнение не требуется.';
					|pl = 'W wierszu jest podany dział. 
					|Dla wydatków od innych rodzajów działalności, wypełnianie nie jest wymagane.';
					|es_ES = 'El departamento está indicado en la línea.
					|No es necesario rellenar para los gastos en otro tipo de actividades.';
					|es_CO = 'El departamento está indicado en la línea.
					|No es necesario rellenar para los gastos en otro tipo de actividades.';
					|tr = 'Dizede bölüm belirtildi. 
					|Diğer faaliyet türlerinde masraflar için doldurulması zorunlu değildir.';
					|it = 'Il reparto è indicato nella stringa. 
					|Per spese di altri tipi di attività, non è richiesta la compilazione.';
					|de = 'Abteilung ist auf Zeichenfolge angegeben. 
					|Für Ausgaben für andere Arten von Aktivitäten ist keine Füllung erforderlich.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"Expenses",
					LineExpense.LineNumber,
					"StructuralUnit",
					Cancel);
				
			EndIf;
			
		Else
			
		EndIf;
		
		If ExpenseItemType = Catalogs.IncomeAndExpenseTypes.CostOfSales Then
			
			If Constants.UseSeveralLinesOfBusiness.Get() AND
				(NOT ValueIsFilled(LineExpense.BusinessLine) OR (LineExpense.BusinessLine = Catalogs.LinesOfBusiness.Other)) Then
				
				TextError = NStr("en = 'The main business activity is not indicated on string. 
					|The basic activity indication is required for cost of sales.'; 
					|ru = 'В строке не указан основной вид предпринимательской деятельности. 
					|Для получения себестоимости продаж требуется указание основного вида деятельности.';
					|pl = 'Podstawowy rodzaj działalności nie jest podany w wierszu. 
					|Dla kosztów sprzedaży jest wymagane wskazanie podstawowego rodzaju działalności.';
					|es_ES = 'La actividad comercial principal no está indicada en la línea
					|Es necesario indicar la actividad básica para calcular el coste de las ventas.';
					|es_CO = 'La actividad comercial principal no está indicada en la línea
					|Es necesario indicar la actividad básica para calcular el coste de las ventas.';
					|tr = 'Dizede esas iş faaliyeti belirtilmedi. 
					|Satış maliyeti için esas faaliyet belirtilmelidir.';
					|it = 'Nella stringa non è indicata la principale attività aziendale. 
					|L''indicazione dell''attività di base è richiesta per il costo di vendite.';
					|de = 'Die Haupttätigkeit ist nicht in der Zeichenfolge angegeben. 
					|Die grundlegende Aktivitätsanzeige wird für die Kosten des Verkaufs benötigt.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					TextError,
					"Expenses",
					LineExpense.LineNumber,
					"BusinessLine",
					Cancel);
				
			EndIf;
			
			If Not ValueIsFilled(LineExpense.StructuralUnit) Then
				
				TextError = NStr("en = 'Department is not indicated on string. 
					|Filling is required for cost of sales at basic activities.'; 
					|ru = 'В строке не указано подразделение. 
					|Для получения себестоимости продаж по основному виду деятельности требуется заполнение.';
					|pl = 'Nie podano działu w wierszu. 
					|Wypełnianie jest wymagane dla kosztów sprzedaży dla podstawowego rodzaju działalności.';
					|es_ES = 'En la línea no está indicado el departamento. 
					|Es necesario rellenar para calcular el coste de las ventas de las actividades básicas.';
					|es_CO = 'En la línea no está indicado el departamento. 
					|Es necesario rellenar para calcular el coste de las ventas de las actividades básicas.';
					|tr = 'Dizede bölüm belirtilmedi. 
					|Esas faaliyetlerdeki satış maliyeti için doldurulması zorunludur.';
					|it = 'Il reparto non è indicato nella stringa. 
					|È richiesta la compilazione per il costo di vendite alle attività di base.';
					|de = 'Abteilung ist nicht in der Zeichenfolge angegeben. 
					|Für die Kosten des Verkaufs bei grundlegenden Aktivitäten ist eine Ausfüllung erforderlich.'"); 
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"Expenses",
					LineExpense.LineNumber,
					"StructuralUnit",
					Cancel);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For Each RowsDirectCost In DirectCost Do
		
		If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			Break;
		EndIf;
		
		If ValueIsFilled(RowsDirectCost.Account) Then
			
			EnumTypeOfAccount = Common.ObjectAttributeValue(RowsDirectCost.Account, "TypeOfAccount");
			
			If Not EnumTypeOfAccount = Enums.GLAccountsTypes.WorkInProgress Then
				
				TextError = NStr("en = 'Cannot post the document. 
					|On the Direct costs tab, specify an account with the Work-in-progress account type.'; 
					|ru = 'Не удается провести документ. 
					|Во вкладке ""Прямые затраты"" укажите счет типа ""Незавершенное производство"".';
					|pl = 'Nie można zatwierdzić dokumentu. 
					|W karcie Koszty bezpośrednie wybierz konto o typie Praca w toku.';
					|es_ES = 'No se puede enviar el documento. 
					|En la pestaña Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|es_CO = 'No se puede enviar el documento. 
					|En la pestaña Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|tr = 'Belge kaydedilemiyor. 
					|Direkt giderler sekmesinde, İşlem bitişi hesap türüne sahip bir hesap belirtin.';
					|it = 'Impossibile pubblicare il documento. 
					|Nella scheda Costi diretti, specificare un conto con tipo di conto Lavori in corso.';
					|de = 'Fehler beim Buchen des Dokuments. 
					|Auf der Registerkarte Direkte Kosten geben Sie ein Konto mit dem Typ Arbeit in Bearbeitung an.'");
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"DirectCost",
					RowsDirectCost.LineNumber,
					"Account",
					Cancel);
					
			EndIf;
				
		EndIf;
		
	EndDo;
	
	For Each RowsDirectCost In DirectCost Do
		
		If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			Break;
		EndIf;
		
		If ValueIsFilled(RowsDirectCost.Account) Then
			
			EnumTypeOfAccount = Common.ObjectAttributeValue(RowsDirectCost.Account, "TypeOfAccount");
			
			If Not EnumTypeOfAccount = Enums.GLAccountsTypes.WorkInProgress Then
				
				TextError = NStr("en = 'Cannot post the document. 
					|On the Direct costs tab, specify an account with the Work-in-progress account type.'; 
					|ru = 'Не удается провести документ. 
					|Во вкладке ""Прямые затраты"" укажите счет типа ""Незавершенное производство"".';
					|pl = 'Nie można zatwierdzić dokumentu. 
					|W karcie Koszty bezpośrednie wybierz konto o typie Praca w toku.';
					|es_ES = 'No se puede enviar el documento. 
					|En la pestaña Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|es_CO = 'No se puede enviar el documento. 
					|En la pestaña Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|tr = 'Belge kaydedilemiyor. 
					|Direkt giderler sekmesinde, İşlem bitişi hesap türüne sahip bir hesap belirtin.';
					|it = 'Impossibile pubblicare il documento. 
					|Nella scheda Costi diretti, specificare un conto con tipo di conto Lavori in corso.';
					|de = 'Fehler beim Buchen des Dokuments. 
					|Auf der Registerkarte Direkte Kosten geben Sie ein Konto mit dem Typ Arbeit in Bearbeitung an.'");
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					TextError,
					"DirectCost",
					RowsDirectCost.LineNumber,
					"Account",
					Cancel);
					
			EndIf;
				
		EndIf;
		
	EndDo;
	
	For Each RowsIndirectExpenses In IndirectExpenses Do
		
		If ValueIsFilled(RowsIndirectExpenses.Account) 
			And Not ValueIsFilled(RowsIndirectExpenses.ClosingAccount) Then
			
			TextError = NStr("en = 'Cannot post the document. 
				|On the Direct costs tab, specify an account Allocate to'; 
				|ru = 'Не удается провести документ. 
				|Во вкладке ""Прямые затраты"" укажите счет в поле ""Разнести на""';
				|pl = 'Nie można zatwierdzić dokumentu. 
				|W karcie Koszty bezpośrednie, wybierz konto Przydziel do';
				|es_ES = 'No se puede enviar el documento.
				|En la pestaña Costes directos, especifique una cuenta Asignar a';
				|es_CO = 'No se puede enviar el documento.
				|En la pestaña Costes directos, especifique una cuenta Asignar a';
				|tr = 'Belge yayınlanamıyor. 
				|Direkt giderler sekmesinde, ""Tahsis et"" hesabı belirtin';
				|it = 'Impossibile pubblicare il documento. 
				|Nella scheda Costi diretti, specificare un conto Allocare a';
				|de = 'Fehler beim Buchen des Dokuments. 
				|Auf der Registerkarte Direkte Kosten geben Sie ein Konto Zuordnen für an'");
				
			DriveServer.ShowMessageAboutError(
				ThisObject, 
				TextError,
				"IndirectExpenses",
				RowsIndirectExpenses.LineNumber,
				"ClosingAccount",
				Cancel);
				
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Initialization of document data
	Documents.Budget.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectCashBudget(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesBudget(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFinancialResultForecast(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
EndProcedure

#EndRegion

#EndIf