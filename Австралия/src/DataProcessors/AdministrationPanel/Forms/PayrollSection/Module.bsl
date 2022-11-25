
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "UsageSettings",	"Enabled", ConstantsSet.UsePayrollSubsystem);
		CommonClientServer.SetFormItemProperty(Items, "PayrollSectionCatalogs","Enabled", ConstantsSet.UsePayrollSubsystem);
		
	EndIf;
	
	// there aren't dependent options requiring accessibility management in section
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" Then
		
		If Not ConstantsSet.UsePayrollSubsystem Then
			
			ConstantsSet.UseSecondaryEmployment = False;
			SaveAttributeValue("ConstantsSet.UseSecondaryEmployment", New Structure());
			
			ConstantsSet.UseHeadcountBudget = False;
			SaveAttributeValue("ConstantsSet.UseHeadcountBudget", New Structure());
			
			ConstantsSet.UsePersonalIncomeTaxCalculation = False;
			SaveAttributeValue("ConstantsSet.UsePersonalIncomeTaxCalculation", New Structure());
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" Then
		
		ConstantsSet.UsePayrollSubsystem = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSecondaryEmployment" Then
		
		ConstantsSet.UseSecondaryEmployment = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UsePersonalIncomeTaxCalculation" Then
		
		ConstantsSet.UsePersonalIncomeTaxCalculation = CurrentValue;
		
	EndIf;
	
EndProcedure

// Procedure to control the disabling of the "Use payroll by registers" option.
//
&AtServer
Function CheckRecordsByPayrollSubsystemRegisters()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	EarningsAndDeductions.Company
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Payroll.Company
	|FROM
	|	AccumulationRegister.Payroll AS Payroll";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Register Earnings and deductions.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en = 'There are items in the ""Earnings and deductions"" catalog. To disable the payroll subsystem, delete these items.'; ru = 'В справочнике ""Начисления и удержания"" есть элементы. Чтобы отключить подсистему ""Зарплата"", удалите эти элементы.';pl = 'Są pozycje w katalogu ""Zarobki i potrącenia"". Aby wyłączyć podsystem listy płac, usuń te elementy.';es_ES = 'Hay elementos en el catálogo ""Ganancias y deducciones"". Para desactivar el subsistema de nómina, elimine estos elementos.';es_CO = 'Hay elementos en el catálogo ""Ganancias y deducciones"". Para desactivar el subsistema de nómina, elimine estos elementos.';tr = '""Kazançlar ve kesintiler"" kataloğunda öğeler var. Bordro alt sistemini devre dışı bırakmak için bu öğeleri silin.';it = 'Ci sono voci  nella anagrafica ""Compensi e trattenute"". Per disattivare il sottosistema Buste paga, cancellare questi elementi.';de = 'Im Verzeichnis ""Bezüge und Abzüge"" gibt es Positionen. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie diese Positionen.'");
		
	EndIf;
	
	// 2. Register Payroll payments.
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Payroll"" document is already in use. To disable the payroll subsystem, delete this document.'; ru = 'Документ ""Начисление зарплаты"" уже используется. Чтобы отключить подсистему ""Зарплата"", удалите этот документ.';pl = 'Dokument ""Płace"" jest już w użyciu. Aby wyłączyć podsystem listy płac, usuń ten dokument.';es_ES = 'El documento ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';es_CO = 'El documento ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';tr = '""Bordro"" belgesi kullanımda. Bordro alt sistemini devre dışı bırakmak için bu belgeyi silin.';it = 'Il documento ""Busta paga"" è già in uso. Per disattivare il sottosistema Buste paga, cancellare questo documento.';de = 'Der Beleg ""Gehaltsabrechnung"" ist bereits in Verwendung. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie dieses Dokument.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Procedure to control the disabling of the "Use salary by documents and catalogs" option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUsePayrollSubsystem()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Payroll.Ref
	|FROM
	|	Document.Payroll AS Payroll
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EarningsAndDeductions.Company,
	|	JobSheet.Ref
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|		LEFT JOIN Document.JobSheet AS JobSheet
	|		ON EarningsAndDeductions.Recorder = JobSheet.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	SalesOrderPerformers.Employee
	|FROM
	|	Document.SalesOrder.Performers AS SalesOrderPerformers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OpeningBalanceEntry.Ref
	|FROM
	|	Document.OpeningBalanceEntry AS OpeningBalanceEntry
	|WHERE
	|	OpeningBalanceEntry.AccountingSection = &AccountingSection
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CashVoucher.Ref
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|WHERE
	|	(CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|			OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	PaymentExpense.Ref
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Employees.Ref
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.PartTime)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EarningAndDeductionTypes.Ref
	|FROM
	|	Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
	|WHERE
	|	EarningAndDeductionTypes.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)";
	
	Query.SetParameter("AccountingSection", Enums.OpeningBalanceAccountingSections.Payroll);
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Document Payroll.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en = '""Payroll"" document is already in use. To disable the payroll subsystem, delete this document.'; ru = 'Документ ""Начисление зарплаты"" уже используется. Чтобы отключить подсистему ""Зарплата"", удалите этот документ.';pl = 'Dokument ""Płace"" jest już w użyciu. Aby wyłączyć podsystem listy płac, usuń ten dokument.';es_ES = 'El documento ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';es_CO = 'El documento ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';tr = '""Bordro"" belgesi kullanımda. Bordro alt sistemini devre dışı bırakmak için bu belgeyi silin.';it = 'Il documento ""Busta paga"" è già in uso. Per disattivare il sottosistema Buste paga, cancellare questo documento.';de = 'Der Beleg ""Gehaltsabrechnung"" ist bereits in Verwendung. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie dieses Dokument.'");
		
	EndIf;
	
	// 2. The Job sheet document
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Timesheet"" document is already in use. To disable the payroll subsystem, delete this document.'; ru = 'Документ ""Табель"" уже используется. Чтобы отключить подсистему ""Зарплата"", удалите этот документ.';pl = 'Dokument ""Arkusz czasu pracy"" jest już w użyciu. Aby wyłączyć podsystem listy płac, usuń ten dokument.';es_ES = 'El documento ""Plantilla horaria"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';es_CO = 'El documento ""Plantilla horaria"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';tr = '""Zaman çizelgesi"" belgesi kullanımda. Bordro alt sistemini devre dışı bırakmak için bu belgeyi silin.';it = 'Il documento ""Timesheet"" è già in uso. Per disattivare il sottosistema Buste paga, cancellare questo documento.';de = 'Das Dokument ""Zeiterfassung"" ist bereits in Gebrauch. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie dieses Dokument.'");
		
	EndIf;
	
	// 3. Document Order - order.
	If Not ResultsArray[2].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Work order"" kind in the infobase that are used to calculate employees'' salary. You cannot clear the ""Salary"" check box.'; ru = 'В информационной базе есть заказы-наряды по которым начисляется зарплата сотрудникам. Снятие флага ""Зарплата"" запрещено.';pl = 'W bazie informacyjnej istnieją dokumenty typu ""Zlecenia pracy"", które służą do obliczania wynagrodzenia pracowników. Nie można oczyścić pola wyboru ""Wynagrodzenie"".';es_ES = 'Hay documentos en el tipo ""Orden de trabajo"" en la infobase que se utilizan para calcular el salario de los empleados. Usted no puede vaciar la casilla de verificación ""Salario"".';es_CO = 'Hay documentos en el tipo ""Orden de trabajo"" en la infobase que se utilizan para calcular el salario de los empleados. Usted no puede vaciar la casilla de verificación ""Salario"".';tr = 'Infobase''de, çalışanların maaşlarını hesaplamak için kullanılan ""İş emri"" türünde belgeler bulunuyor. ""Maaş"" onay kutusu silinemez.';it = 'Ci sono documenti del tipo ""Commessa"" nel infobase che vengono utilizzati per calcolare lo stipendio dei dipendenti. Non è possibile deselezionare la casella di controllo ""Stipendio"".';de = 'In der Infobase gibt es Dokumente der Art ""Arbeitsauftrag"", die zur Berechnung des Gehalts der Mitarbeiter verwendet werden. Sie können das Kontrollkästchen ""Gehalt"" nicht deaktivieren.'");
		
	EndIf;
	
	// 4. Document Enter opening balance.
	If Not ResultsArray[3].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +  NStr("en = '""Opening balance entry"" document of ""Salary payable balance"" operation type is already in use. To disable the payroll subsystem, delete this document.'; ru = 'Документ ""Ввод начальных остатков"" с типом ""Остатки по расчетам с персоналом"" уже используется. Чтобы отключить подсистему ""Зарплата"", удалите этот документ.';pl = 'Dokument ""Wprowadzenie salda początkowego"" typu operacji ""Saldo wypłacane wynagrodzenie"" jest już w użyciu. Aby wyłączyć podsystem listy płac, usuń ten dokument.';es_ES = 'El documento ""Saldo inicial"" del tipo de operación ""Saldo del salario pagable"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';es_CO = 'El documento ""Saldo inicial"" del tipo de operación ""Saldo del salario pagable"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';tr = '""Maaş ödenebilir bakiye"" işlem türündeki ""Açılış bakiyesi girişi"" belgesi zaten kullanımda. Bordro alt sistemini devre dışı bırakmak için bu belgeyi silin.';it = 'Il documento ""Inserimento saldo di apertura"" del operazione ""Saldo stipendi da pagare"" è già in uso. Per disattivare il sottosistema Buste paga, cancellare questo documento.';de = 'Der Beleg ""Anfangssaldo-Buchung"" des Operationstyps ""Saldo des zu zahlenden Gehalts"" ist bereits in Verwendung. Um das Lohn- und Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie dieses Dokument.'");
		
	EndIf;
	
	// 5. Document Cash payment.
	If Not ResultsArray[4].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Cash voucher"" document of ""Salary to employee"" or ""Payroll"" operation type is already in use. To disable the payroll subsystem, delete this document.'; ru = 'Документ ""Расходный кассовый ордер"" с типом ""Зарплата сотруднику"" или ""Выплата заработной платы"" уже используется. Чтобы отключить подсистему ""Зарплата"", удалите этот документ.';pl = 'Dokument ""Dowód kasowy KW"" typu operacji ""Wynagrodzenie dla pracownika"" lub ""Lista płac"" jest już w użyciu. Aby wyłączyć podsystem listy płac, usuń ten dokument.';es_ES = 'El documento ""Bono en efectivo"" del tipo de operación ""Salario para empleado"" o ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';es_CO = 'El documento ""Bono en efectivo"" del tipo de operación ""Salario para empleado"" o ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';tr = '""Çalışana Maaş"" veya ""Bordro"" işlem türünün ""Kasa fişi"" belgesi zaten kullanılıyor. Bordro alt sistemini devre dışı bırakmak için bu belgeyi silin.';it = 'Il documento ""Uscita di cassa"" di ""Stipendio al dipendente"" o operazione ""Busta paga"" è già in uso. Per disattivare il sottosistema Buste paga, cancellare questo documento.';de = 'Der Beleg ""Kassenbeleg"" des Operationstyps ""Gehalt an Mitarbeiter"" oder ""Lohn- und Gehaltsabrechnung"" wird bereits verwendet. Um das Lohn und Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie dieses Dokument.'");
		
	EndIf;
	
	// 6. Document Bank payment.
	If Not ResultsArray[5].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Bank payment"" document of ""Payroll"" operation type is already in use. To disable the payroll subsystem, delete this document.'; ru = 'Документ ""Списание со счета"" с типом ""Выплата заработной платы"" уже используется. Чтобы отключить подсистему ""Зарплата"", удалите этот документ.';pl = 'Dokument ""Płatności bankowe"" typu operacji ""Wynagrodzenie dla pracownika"" jest już w użyciu. Aby wyłączyć podsystem listy płac, usuń ten dokument.';es_ES = 'El documento ""Pago bancario"" del tipo de operación ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';es_CO = 'El documento ""Pago bancario"" del tipo de operación ""Nómina"" se usa ya. Para desactivar el subsistema de nómina, elimine este documento.';tr = '""Bordro"" işlem türündeki ""Banka ödemesi"" belgesi kullanımda. Bordro alt sistemini devre dışı bırakmak için bu belgeyi silin.';it = 'Documento ""Pagamento bancario"" del tipo di operazione ""Busta paga"" è già in uso. Per disattivare il sottosistema Buste paga, cancellare questo documento.';de = 'Der Beleg ""Überweisung"" des Operationstyps ""Lohn und Gehalt"" ist bereits in Verwendung. Um das Untersystem von Lohn und Gehalt zu deaktivieren, löschen Sie dieses Dokument.'");
		
	EndIf;
	
	// 7. Catalog Employees.
	If Not ResultsArray[6].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are secondary employment employees. To disable the payroll subsystem, delete these records.'; ru = 'Существуют сотрудники по совместительству. Чтобы удалить подсистему ""Зарплата"", необходимо удалить записи по ним.';pl = 'Istnieją inni pracownicy zatrudnieni dodatkowo. Aby wyłączyć podsystem listy płac, usuń te zapisy.';es_ES = 'Hay pluriempleados. Para desactivar el subsistema de nómina, elimine este registro.';es_CO = 'Hay pluriempleados. Para desactivar el subsistema de nómina, elimine este registro.';tr = 'İkincil istihdam çalışanı var. Bordro alt sistemini devre dışı bırakmak için bu kayıtları silin.';it = 'Ci sono occupazioni secondarie dei dipendenti. Per disattivare il sottosistema Buste paga, cancellare queste registrazioni.';de = 'Es gibt nebenberufliche Mitarbeiter. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie diese Datensätze.'");	
		
	EndIf;
	
	// 8. Catalog Earning and deduction types.
	If Not ResultsArray[7].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are items in the ""Earnings and deductions"" catalog of the tax type. To disable the payroll subsystem, delete these items.'; ru = 'В справочнике ""Начисления и удержания"" есть элементы с типом ""Налоги"". Чтобы отключить подсистему ""Зарплата"", удалите эти элементы.';pl = 'Są pozycje w katalogu rodzaju podatków. ""Zarobki i potrącenia"". Aby wyłączyć podsystem listy płac, usuń te elementy.';es_ES = 'Hay elementos del tipo de impuestos en el catálogo ""Ganancias y deducciones"". Para desactivar el subsistema de nómina, elimine estos elementos.';es_CO = 'Hay elementos del tipo de impuestos en el catálogo ""Ganancias y deducciones"". Para desactivar el subsistema de nómina, elimine estos elementos.';tr = 'Vergi tipinin ""Kazanç ve kesintiler"" kataloğunda bazı öğeler var. Bordro alt sistemini devre dışı bırakmak için bu öğeleri silin.';it = 'Ci sono voci nella anagrafica ""Compensi e trattenute"" del tipo imposta. Per disattivare il sottosistema Buste paga, cancellare queste voci.';de = 'Im Verzeichnis ""Bezüge und Abzüge"" gibt es Positionen zur Steuerart. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie diese Positionen.'");
		
	EndIf;
	
	If IsBlankString(ErrorText) Then
		
		ErrorText = CheckRecordsByPayrollSubsystemRegisters();
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the possibility of option disable UseJobsharing.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseJobsharing()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Employees.Ref
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.PartTime)";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are secondary employment employees. To disable the secondary employment, delete these records.'; ru = 'Существуют сотрудники по совместительству. Чтобы отключить возможность совместительств, необходимо удалить записи по ним.';pl = 'Istnieją inni pracownicy zatrudnieni dodatkowo. Aby wyłączyć dodatkowe zatrudnienie, usuń te, usuń te zapisy.';es_ES = 'Hay pluriempleados. Para desactivar el subsistema de nómina, elimine estos registros.';es_CO = 'Hay pluriempleados. Para desactivar el subsistema de nómina, elimine estos registros.';tr = 'İkincil istihdam çalışanları var. İkincil istihdamı devre dışı bırakmak için bu kayıtları silin.';it = 'Ci sono seconde occupazioni dipendenti. Per disattivare le occupazioni secondari, eleminare queste registrazioni.';de = 'Es gibt nebenberufliche Mitarbeiter. Um die Nebenbeschäftigung zu deaktivieren, löschen Sie diese Datensätze.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the possibility of option disable UsePersonalIncomeTaxCalculation.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingDoIncomeTax()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	EarningAndDeductionTypes.Ref
		|FROM
		|	Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
		|WHERE
		|	EarningAndDeductionTypes.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are items in the ""Earnings and deductions"" catalog of the tax type. To disable the payroll subsystem, delete these items.'; ru = 'В справочнике ""Начисления и удержания"" есть элементы с типом ""Налоги"". Чтобы отключить подсистему ""Зарплата"", удалите эти элементы.';pl = 'Są pozycje rodzaju podatków w katalogu ""Zarobki i potrącenia"". Aby wyłączyć podsystem listy płac, usuń te elementy.';es_ES = 'Hay elementos del tipo de impuestos en el catálogo ""Ganancias y deducciones"". Para desactivar el subsistema de nómina, elimine estos elementos.';es_CO = 'Hay elementos del tipo de impuestos en el catálogo ""Ganancias y deducciones"". Para desactivar el subsistema de nómina, elimine estos elementos.';tr = 'Vergi tipinin ""Kazanç ve kesintiler"" kataloğunda bazı öğeler var. Bordro alt sistemini devre dışı bırakmak için bu öğeleri silin.';it = 'Ci sono voci nella anagrafica ""Compensi e trattenute"" del tipo imposta. Per disattivare il sottosistema Buste paga, cancellare queste voci.';de = 'Im Verzeichnis ""Bezüge und Abzüge"" gibt es Positionen zur Steuerart. Um das Gehaltsabrechnungsuntersystem zu deaktivieren, löschen Sie diese Positionen.'");	
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Enable/disable  Payroll section
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" Then
	
		If Constants.UsePayrollSubsystem.Get() <> ConstantsSet.UsePayrollSubsystem
			AND (NOT ConstantsSet.UsePayrollSubsystem) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUsePayrollSubsystem();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If the catalog Employees there are part-time workers then it is not allowed to delete flag UseSecondaryEmployment
	If AttributePathToData = "ConstantsSet.UseSecondaryEmployment" Then
		
		If Constants.UseSecondaryEmployment.Get() <> ConstantsSet.UseSecondaryEmployment
			AND (NOT ConstantsSet.UseSecondaryEmployment) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseJobsharing();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are catalog items "Earning and deduction kinds" with type "Tax" then it is not allowed to delete flag UsePersonalIncomeTaxCalculation
	If AttributePathToData = "ConstantsSet.UsePersonalIncomeTaxCalculation" Then
		
		If Constants.UsePersonalIncomeTaxCalculation.Get() <> ConstantsSet.UsePersonalIncomeTaxCalculation
			AND (NOT ConstantsSet.UsePersonalIncomeTaxCalculation) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingDoIncomeTax();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange field UsePayrollSubsystem.
&AtClient
Procedure FunctionalOptionUseSubsystemPayrollOnChange(Item)
	
	If ConstantsSet.UsePayrollSubsystem Then
		ConstantsSetOnChange("UsePayrollSubsystem", Item);
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure ConstantsSetOnChange(StringNameConstant, Item)
	
	StructureParameters = New Structure("NameConstant, Item", StringNameConstant, Item);
	Notification = New NotifyDescription("ConstantsSetOnChangeEnd", ThisObject, StructureParameters);
	
	TextQuestion = NStr("en = 'The legacy Payroll subsystem will be available for you. 
		|For this subsystem, the vendor support is limited. 
		|Do you want to continue?'; 
		|ru = 'Для вас будет доступна старая подсистема Зарплата. 
		|Для этой подсистемы поддержка поставщика ограничена. 
		|Продолжить?';
		|pl = 'Starszy podsystem Lista płac będzie dostępny dla ciebie. 
		|Dla tego podsystemu, wsparcie dostawców jest ograniczone. 
		|Czy chcesz kontynuować?';
		|es_ES = 'El subsistema de nómina heredado estará disponible para usted.
		|Para este subsistema, el soporte del proveedor es limitado. 
		|¿Quiere continuar?';
		|es_CO = 'El subsistema de nómina heredado estará disponible para usted.
		|Para este subsistema, el soporte del proveedor es limitado. 
		|¿Quiere continuar?';
		|tr = 'Bordro alt sistemine erişebileceksiniz. 
		|Bu alt sistem için satıcı desteği sınırlıdır. 
		|Devam etmek istiyor musunuz?';
		|it = 'Il sottosistema legacy libro paga è disponibile. 
		|Il supporto fornitori è limitato per questo sottosistema. 
		|Continuare?';
		|de = 'Das veraltete Lohn-und-Gehalt-Subsystem steht Ihnen zur Verfügung. 
		|Für dieses Subsystem ist die Lieferantenunterstützung begrenzt. 
		|Möchten Sie fortfahren?'"); 
	
	Mode = QuestionDialogMode.YesNo;
	ShowQueryBox(Notification, TextQuestion, Mode, 0);
	
EndProcedure
	
&AtClient
Procedure ConstantsSetOnChangeEnd(Result, StructureParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Attachable_OnAttributeChange(StructureParameters.Item);
		
	Else 
		
		ConstantsSet[StructureParameters.NameConstant] = False;
		
	EndIf;
	
EndProcedure

// Procedure - ref click handler FunctionalOptionDoStaffScheduleHelp.
//
&AtClient
Procedure FunctionalOptionDoStaffScheduleOnChange(Item)
	
	If ConstantsSet.UseHeadcountBudget Then
		ConstantsSetOnChange("UseHeadcountBudget", Item);
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionUseJobsharing.
//
&AtClient
Procedure FunctionalOptionUseJobSharingOnChange(Item)
	
	If ConstantsSet.UseSecondaryEmployment Then
		ConstantsSetOnChange("UseSecondaryEmployment", Item);
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionReflectIncomeTaxes.
&AtClient
Procedure FunctionalOptionToReflectIncomeTaxesOnChange(Item)
	
	If ConstantsSet.UsePersonalIncomeTaxCalculation Then
		ConstantsSetOnChange("UsePersonalIncomeTaxCalculation", Item);
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion