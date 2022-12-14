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
					|ru = '?? ???????????? ???? ?????????????? ??????????????????????????. 
					|?????? ?????????????????? ?????????????? ???? ?????????????????? ???????? ???????????????????????? ?????????????????? ????????????????????.';
					|pl = 'Dzia?? nie jest podany w wierszu. 
					|Wymagane jest wype??nianie dla przychod??w z podstawowej dzia??alno??ci.';
					|es_ES = 'En la l??nea no est?? indicado el departamento. 
					|Se debe rellenar para obtener los ingresos de la actividad b??sica.';
					|es_CO = 'En la l??nea no est?? indicado el departamento. 
					|Se debe rellenar para obtener los ingresos de la actividad b??sica.';
					|tr = 'Dizede b??l??m belirtilmedi. 
					|Temel faaliyet gelirleri i??in doldurmas?? zorunludur.';
					|it = 'Il reparto non ?? indicato nella stringa. 
					|Sono richieste le compilazioni per le entrate di attivit?? di base.';
					|de = 'Abteilung ist in der Zeichenfolge nicht angegeben. 
					|F??llungen sind erforderlich f??r grundlegende Aktivit??tseinnahmen.'"); 
				
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
					|ru = '?????????????????? ?? ???????????? ?????? ???????????????????????? ???????????????????? ???? ''????????????''. 
					|?????? ?????????????? ???????????? ???????????????????? ?????????????? ???????????? ?????? ????????????????????????.';
					|pl = 'Typ rodzaju dzia??alno??ci wybrany w wierszu r????ni si?? od ''Inne''. 
					|Dla innych dochod??w, konieczne jest okre??lenie innego typu rodzaju dzia??alno??ci.';
					|es_ES = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros ingresos, es necesario especificar otro tipo de actividad.';
					|es_CO = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros ingresos, es necesario especificar otro tipo de actividad.';
					|tr = 'Sat??rda belirtilen faaliyet t??r?? ""Di??er""den farkl??. 
					|Di??er gelirler i??in di??er faaliyet t??r?? belirtilmelidir.';
					|it = 'Il tipo di attivit?? specificato nella riga ?? diverso da ''Altro''. 
					|Per altri ricavi ?? necessario specificare l''altro tipo di attivit??.';
					|de = 'Der in der Zeile angegebene Aktivit??tstyp unterscheidet sich von ''Anderes''. 
					|F??r sonstige Einnahmen ist es notwendig, den anderen Aktivit??tstyp anzugeben.'"); 
				
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
					|ru = '?? ???????????? ?????????????? ??????????????????????????. 
					|?????? ?????????????????? ?????????????? ???? ???????????? ?????????? ?????????????????????????????????????? ???????????????????????? ???????????????????? ???? ??????????????????.';
					|pl = 'Dzie?? jest podany w wierszu. 
					|Dla przychod??w od innych rodzaj??w dzia??alno??ci biznesowej, wype??nianie nie jest wymagane.';
					|es_ES = 'El departamento est?? indicado en la l??nea.
					|No es necesario rellenar para los ingresos de otros tipos de actividad comercial.';
					|es_CO = 'El departamento est?? indicado en la l??nea.
					|No es necesario rellenar para los ingresos de otros tipos de actividad comercial.';
					|tr = 'Dizede b??l??m belirtildi. 
					|Di??er i?? faaliyeti t??rlerinden elde edilen gelirler i??in doldurulmas?? zorunlu de??ildir.';
					|it = 'Il reparto ?? indicato nella stringa. 
					|Per il ricavo da altri tipi di attivit?? aziendale, non ?? richiesta la compilazione.';
					|de = 'Abteilung ist auf Zeichenfolge angegeben. 
					|F??r die Einnahmen aus anderen Gesch??ftst??tigkeiten ist keine F??llung erforderlich.'"); 
				
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
				
				TextError = NStr("en = 'Activity direction is indicated on string.'; ru = '?????????????????????? ???????????????????????? ?????????????? ?? ????????????.';pl = 'Rodzaj dzia??alno??ci jest podany w wierszu.';es_ES = 'La direcci??n de la actividad se ha indicado en la l??nea.';es_CO = 'La direcci??n de la actividad se ha indicado en la l??nea.';tr = 'Dizede faaliyet y??n?? belirtildi.';it = 'La direzione dell''attivit?? ?? indicata sulla stringa.';de = 'Die Aktivit??tsrichtung wird in der Zeichenfolge angezeigt.'");
				
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
					|ru = '?????????????????? ?? ???????????? ?????? ???????????????????????? ???????????????????? ???? ''????????????''. 
					|?????? ???????????? ???????????????? ???????????????????? ?????????????? ???????????? ?????? ????????????????????????.';
					|pl = 'Podany rodzaj dzia??alno??ci okre??lony r????ni si?? od ''Inne''. 
					|Dla innych wydatk??w nale??y poda?? inny rodzaj dzia??alno??ci.';
					|es_ES = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros gastos, es necesario especificar otro tipo de actividad.';
					|es_CO = 'El tipo de actividad especificado en la fila difiere de ""Otro"".
					|Para otros gastos, es necesario especificar otro tipo de actividad.';
					|tr = 'Sat??rda belirtilen faaliyet t??r?? ""Di??er""den farkl??. 
					|Di??er masraflar i??in di??er faaliyet t??r?? belirtilmelidir.';
					|it = 'Il tipo di attivit?? specificato nella riga ?? diverso da ''Altro''. 
					|Per altre spese ?? necessario specificare l''altro tipo di attivit??.';
					|de = 'Der in der Zeile angegebene Aktivit??tstyp unterscheidet sich von ''Anderes''. 
					|F??r sonstige Ausgaben ist es notwendig, den anderen Aktivit??tstyp anzugeben.'"); 
				
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
					|ru = '?? ???????????? ?????????????? ??????????????????????????. 
					|?????? ?????????????????? ?????????????? ???? ???????????? ?????????? ???????????????????????? ???????????????????? ???? ??????????????????.';
					|pl = 'W wierszu jest podany dzia??. 
					|Dla wydatk??w od innych rodzaj??w dzia??alno??ci, wype??nianie nie jest wymagane.';
					|es_ES = 'El departamento est?? indicado en la l??nea.
					|No es necesario rellenar para los gastos en otro tipo de actividades.';
					|es_CO = 'El departamento est?? indicado en la l??nea.
					|No es necesario rellenar para los gastos en otro tipo de actividades.';
					|tr = 'Dizede b??l??m belirtildi. 
					|Di??er faaliyet t??rlerinde masraflar i??in doldurulmas?? zorunlu de??ildir.';
					|it = 'Il reparto ?? indicato nella stringa. 
					|Per spese di altri tipi di attivit??, non ?? richiesta la compilazione.';
					|de = 'Abteilung ist auf Zeichenfolge angegeben. 
					|F??r Ausgaben f??r andere Arten von Aktivit??ten ist keine F??llung erforderlich.'"); 
				
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
					|ru = '?? ???????????? ???? ???????????? ???????????????? ?????? ?????????????????????????????????????? ????????????????????????. 
					|?????? ?????????????????? ?????????????????????????? ???????????? ?????????????????? ???????????????? ?????????????????? ???????? ????????????????????????.';
					|pl = 'Podstawowy rodzaj dzia??alno??ci nie jest podany w wierszu. 
					|Dla koszt??w sprzeda??y jest wymagane wskazanie podstawowego rodzaju dzia??alno??ci.';
					|es_ES = 'La actividad comercial principal no est?? indicada en la l??nea
					|Es necesario indicar la actividad b??sica para calcular el coste de las ventas.';
					|es_CO = 'La actividad comercial principal no est?? indicada en la l??nea
					|Es necesario indicar la actividad b??sica para calcular el coste de las ventas.';
					|tr = 'Dizede esas i?? faaliyeti belirtilmedi. 
					|Sat???? maliyeti i??in esas faaliyet belirtilmelidir.';
					|it = 'Nella stringa non ?? indicata la principale attivit?? aziendale. 
					|L''indicazione dell''attivit?? di base ?? richiesta per il costo di vendite.';
					|de = 'Die Hauptt??tigkeit ist nicht in der Zeichenfolge angegeben. 
					|Die grundlegende Aktivit??tsanzeige wird f??r die Kosten des Verkaufs ben??tigt.'"); 
				
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
					|ru = '?? ???????????? ???? ?????????????? ??????????????????????????. 
					|?????? ?????????????????? ?????????????????????????? ???????????? ???? ?????????????????? ???????? ???????????????????????? ?????????????????? ????????????????????.';
					|pl = 'Nie podano dzia??u w wierszu. 
					|Wype??nianie jest wymagane dla koszt??w sprzeda??y dla podstawowego rodzaju dzia??alno??ci.';
					|es_ES = 'En la l??nea no est?? indicado el departamento. 
					|Es necesario rellenar para calcular el coste de las ventas de las actividades b??sicas.';
					|es_CO = 'En la l??nea no est?? indicado el departamento. 
					|Es necesario rellenar para calcular el coste de las ventas de las actividades b??sicas.';
					|tr = 'Dizede b??l??m belirtilmedi. 
					|Esas faaliyetlerdeki sat???? maliyeti i??in doldurulmas?? zorunludur.';
					|it = 'Il reparto non ?? indicato nella stringa. 
					|?? richiesta la compilazione per il costo di vendite alle attivit?? di base.';
					|de = 'Abteilung ist nicht in der Zeichenfolge angegeben. 
					|F??r die Kosten des Verkaufs bei grundlegenden Aktivit??ten ist eine Ausf??llung erforderlich.'"); 
				
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
					|ru = '???? ?????????????? ???????????????? ????????????????. 
					|???? ?????????????? ""???????????? ??????????????"" ?????????????? ???????? ???????? ""?????????????????????????? ????????????????????????"".';
					|pl = 'Nie mo??na zatwierdzi?? dokumentu. 
					|W karcie Koszty bezpo??rednie wybierz konto o typie Praca w toku.';
					|es_ES = 'No se puede enviar el documento. 
					|En la pesta??a Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|es_CO = 'No se puede enviar el documento. 
					|En la pesta??a Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|tr = 'Belge kaydedilemiyor. 
					|Direkt giderler sekmesinde, ????lem biti??i hesap t??r??ne sahip bir hesap belirtin.';
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
					|ru = '???? ?????????????? ???????????????? ????????????????. 
					|???? ?????????????? ""???????????? ??????????????"" ?????????????? ???????? ???????? ""?????????????????????????? ????????????????????????"".';
					|pl = 'Nie mo??na zatwierdzi?? dokumentu. 
					|W karcie Koszty bezpo??rednie wybierz konto o typie Praca w toku.';
					|es_ES = 'No se puede enviar el documento. 
					|En la pesta??a Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|es_CO = 'No se puede enviar el documento. 
					|En la pesta??a Gastos directos, especifique una cuenta con el tipo cuenta Trabajo en progreso.';
					|tr = 'Belge kaydedilemiyor. 
					|Direkt giderler sekmesinde, ????lem biti??i hesap t??r??ne sahip bir hesap belirtin.';
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
				|ru = '???? ?????????????? ???????????????? ????????????????. 
				|???? ?????????????? ""???????????? ??????????????"" ?????????????? ???????? ?? ???????? ""???????????????? ????""';
				|pl = 'Nie mo??na zatwierdzi?? dokumentu. 
				|W karcie Koszty bezpo??rednie, wybierz konto Przydziel do';
				|es_ES = 'No se puede enviar el documento.
				|En la pesta??a Costes directos, especifique una cuenta Asignar a';
				|es_CO = 'No se puede enviar el documento.
				|En la pesta??a Costes directos, especifique una cuenta Asignar a';
				|tr = 'Belge yay??nlanam??yor. 
				|Direkt giderler sekmesinde, ""Tahsis et"" hesab?? belirtin';
				|it = 'Impossibile pubblicare il documento. 
				|Nella scheda Costi diretti, specificare un conto Allocare a';
				|de = 'Fehler beim Buchen des Dokuments. 
				|Auf der Registerkarte Direkte Kosten geben Sie ein Konto Zuordnen f??r an'");
				
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