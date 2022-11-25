#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	ReportSettings.DefineFormSettings = True;

	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanes(Settings, ReportSettings, False);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettings.Details = NStr("ru = 'Универсальный отчет по справочникам, документам, регистрам.'; en = 'Universal report on catalogs, documents, registers.'; pl = 'Uniwersalne sprawozdanie dot. raportów, katalogów, dokumentów, rejestrów.';es_ES = 'Informe universal por catálogos, documentos, registros.';es_CO = 'Informe universal por catálogos, documentos, registros.';tr = 'Kılavuzlar, belgeler, kayıtlar ile ilgili üniversal rapor';it = 'Report universale sulle anagrafiche, documenti, registri.';de = 'Universeller Bericht über Kataloge, Dokumente, Register.'");
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

Function TextOfQueryByMetadata(ReportParameters)
	SourceMetadata = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
	
	SourceName = SourceMetadata.FullName();
	If ValueIsFilled(ReportParameters.TableName) Then 
		SourceName = SourceName + "." + ReportParameters.TableName;
	EndIf;
	
	SourceFilter = "";
	
	If ReportParameters.TableName = "BalanceAndTurnovers"
		Or ReportParameters.TableName = "Turnovers" Then
		SourceFilter = "({&BeginOfPeriod}, {&EndOfPeriod}, Auto)";
	ElsIf ReportParameters.TableName = "Balance"
		Or ReportParameters.TableName = "SliceLast" Then
		SourceFilter = "({&EndOfPeriod},)";
	ElsIf ReportParameters.TableName = "SliceFirst" Then
		SourceFilter = "({&BeginOfPeriod},)";
	ElsIf ReportParameters.MetadataObjectType = "Documents" 
		Or ReportParameters.MetadataObjectType = "Tasks"
		Or ReportParameters.MetadataObjectType = "BusinessProcesses" Then
		
		SourceName = SourceName + " AS Table";
		
		If ValueIsFilled(ReportParameters.TableName)
			AND CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "TabularSections")
			AND CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata.TabularSections, ReportParameters.TableName) Then 
			SourceFilter = "
				|{WHERE
				|	(Ref.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
		Else
			SourceFilter = "
				|{WHERE
				|	(Date BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
		EndIf;
	ElsIf ReportParameters.MetadataObjectType = "InformationRegisters"
		AND SourceMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		SourceFilter = "
			|{WHERE
			|	(Period BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
	ElsIf ReportParameters.MetadataObjectType = "AccumulationRegisters"
		Or ReportParameters.MetadataObjectType = "AccountingRegisters" Then
		SourceFilter = "
			|{WHERE
			|	(Period BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
	ElsIf ReportParameters.MetadataObjectType = "CalculationRegisters" Then
		SourceFilter = "
			|{WHERE
			|	RegistrationPeriod BETWEEN &BeginOfPeriod AND &EndOfPeriod}";
	EndIf;
	
	QueryText = "
	|SELECT ALLOWED
	|	*
	|FROM
	|	&SourceName";
	
	QueryText = StrReplace(QueryText, "&SourceName", SourceName);
	
	If ValueIsFilled(SourceFilter) Then
		QueryText = QueryText + SourceFilter;
	EndIf;
	
	Return QueryText;
	
EndFunction

Function AvailableMetadataObjectsTypes() Export
	
	ValuesForSelection = New ValueList;
	
	If HasMetadataTypeObjects(Metadata.Documents) Then
		ValuesForSelection.Add("Documents", NStr("ru = 'Документ'; en = 'Document'; pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"), , PictureLib.Document);
	EndIf;
	If HasMetadataTypeObjects(Metadata.Catalogs) Then
		ValuesForSelection.Add("Catalogs", NStr("ru = 'Справочник'; en = 'Catalog'; pl = 'Katalog';es_ES = 'Catálogo';es_CO = 'Catálogo';tr = 'Katalog';it = 'Anagrafica';de = 'Katalog'"), , PictureLib.Catalog);
	EndIf;
	If HasMetadataTypeObjects(Metadata.AccumulationRegisters) Then
		ValuesForSelection.Add("AccumulationRegisters", NStr("ru = 'Регистр накопления'; en = 'Accumulation register'; pl = 'Rejestr akumulacji';es_ES = 'Registro de acumulación';es_CO = 'Registro de acumulación';tr = 'Birikeç';it = 'Registro di accumulo';de = 'Akkumulationsregister'"), , PictureLib.AccumulationRegister);
	EndIf;
	If HasMetadataTypeObjects(Metadata.InformationRegisters) Then
		ValuesForSelection.Add("InformationRegisters", NStr("ru = 'Регистр сведений'; en = 'Information register'; pl = 'Rejestr informacji';es_ES = 'Registro de información';es_CO = 'Registro de información';tr = 'Bilgi kaydı';it = 'Registro informazioni';de = 'Informationsregister'"), , PictureLib.InformationRegister);
	EndIf;
	If HasMetadataTypeObjects(Metadata.AccountingRegisters) Then
		ValuesForSelection.Add("AccountingRegisters", NStr("ru = 'Регистр бухгалтерии'; en = 'Accounting register'; pl = 'Rejestr księgowy';es_ES = 'Registro de contabilidad';es_CO = 'Registro de contabilidad';tr = 'Muhasebe kaydı';it = 'Registro contabile';de = 'Buchhaltungsregister'"), , PictureLib.AccountingRegister);
	EndIf;
	If HasMetadataTypeObjects(Metadata.CalculationRegisters) Then
		ValuesForSelection.Add("CalculationRegisters", NStr("ru = 'Регистр расчета'; en = 'Calculation register'; pl = 'Rejestr kalkulacji';es_ES = 'Registro de cálculos';es_CO = 'Registro de cálculos';tr = 'Hesaplama kaydı';it = 'Registro di calcolo';de = 'Berechnungsregister'"), , PictureLib.CalculationRegister);
	EndIf;
	If HasMetadataTypeObjects(Metadata.ChartsOfCalculationTypes) Then
		ValuesForSelection.Add("ChartsOfCalculationTypes", NStr("ru = 'Планы видов расчета'; en = 'Charts of calculation types'; pl = 'Plany typów obliczeń';es_ES = 'Diagramas de los tipos de cálculos';es_CO = 'Diagramas de los tipos de cálculos';tr = 'Hesaplama türleri çizelgeleri';it = 'Grafici di tipi di calcolo';de = 'Diagramme der Berechnungstypen'"), , PictureLib.ChartOfCalculationTypes);
	EndIf;
	If HasMetadataTypeObjects(Metadata.BusinessProcesses) Then
		ValuesForSelection.Add("BusinessProcesses", NStr("ru = 'Бизнес-процессы'; en = 'Business processes'; pl = 'Procesy biznesowe';es_ES = 'Procesos de negocio';es_CO = 'Procesos de negocio';tr = 'İş süreçleri';it = 'Processi di business';de = 'Geschäftsprozesse'"), , PictureLib.BusinessProcess);
	EndIf;
	If HasMetadataTypeObjects(Metadata.Tasks) Then
		ValuesForSelection.Add("Tasks", NStr("ru = 'Задач'; en = 'Tasks'; pl = 'Zadania';es_ES = 'Tareas';es_CO = 'Tareas';tr = 'Görevler';it = 'Compiti';de = 'Aufgaben'"), , PictureLib.Task);
	EndIf;
	
	Return ValuesForSelection;
	
EndFunction

Function AvailableMetadataObjects(DCSettings, MetadataObjectType = "") Export
	
	ValuesForSelection = New ValueList;
	ObjectsToDelete  = New ValueList;
	
	If IsBlankString(MetadataObjectType) Then
		ReportParameters = DCSettings.DataParameters.Items;
		MetadataObjectTypeParameter = ReportParameters.Find("MetadataObjectType");
		MetadataObjectType = MetadataObjectTypeParameter.Value;
	EndIf;
	If MetadataObjectType <> Undefined AND Not IsBlankString(MetadataObjectType) Then
		For each Object In Metadata[MetadataObjectType] Do
			If Not Common.MetadataObjectAvailableByFunctionalOptions(Object)
				Or Not AccessRight("Read", Object) Then
				Continue;
			EndIf;
			If Lower(Left(Object.Name, 7)) = "delete" Then
				ObjectsToDelete.Add(Object.Name, Object.Synonym);
			Else
				ValuesForSelection.Add(Object.Name, Object.Synonym);
			EndIf;
		EndDo;
		ValuesForSelection.SortByPresentation(SortDirection.Asc);
		ObjectsToDelete.SortByPresentation(SortDirection.Asc);
		
		For Each ObjectToDelete In ObjectsToDelete Do
			ValuesForSelection.Add(ObjectToDelete.Value, ObjectToDelete.Presentation);
		EndDo;
		
	EndIf;
	
	Return ValuesForSelection;
	
EndFunction

Function AvailableTables(DCSettings, MetadataObjectType = "", MetadataObjectName = "") Export
	
	ValuesForSelection = New ValueList;
	
	IsImportedSchema = DCSettings.AdditionalProperties.Property("DataCompositionSchema");
	
	ReportParameters = DCSettings.DataParameters.Items;
	DataSourceParameter = ReportParameters.Find("DataSource");
	MetadataObjectTypeParameter = ReportParameters.Find("MetadataObjectType");
	MetadataObjectNameParameter = ReportParameters.Find("MetadataObjectName");
	
	If IsBlankString(MetadataObjectType) Then
		MetadataObjectType = MetadataObjectTypeParameter.Value;
	EndIf;
	
	If IsBlankString(MetadataObjectName) Then
		MetadataObjectName = MetadataObjectNameParameter.Value;
	EndIf;
	
	If (NOT ValueIsFilled(MetadataObjectType) 
		OR NOT ValueIsFilled(MetadataObjectName))
		AND NOT DCSettings.AdditionalProperties.Property("DataCompositionSchema") Then
		Return ValuesForSelection;
	EndIf;
	
	ValuesForSelection.Add("", NStr("ru = 'Основные данные'; en = 'Main data'; pl = 'Dane podstawowe';es_ES = 'Datos principales';es_CO = 'Datos principales';tr = 'Ana veri';it = 'Dati principali';de = 'Hauptdaten'"));
	If MetadataObjectType = "Documents" 
		OR MetadataObjectType = "Tasks"
		OR MetadataObjectType = "BusinessProcesses"
		OR MetadataObjectType = "Catalogs" Then
		For each TabularSection In Metadata[MetadataObjectType][MetadataObjectName].TabularSections Do
			ValuesForSelection.Add(TabularSection.Name, TabularSection.Synonym);
		EndDo;
	ElsIf MetadataObjectType = "AccumulationRegisters" Then
		If Metadata[MetadataObjectType][MetadataObjectName].RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			ValuesForSelection.Add("BalanceAndTurnovers", NStr("ru = 'Остатки и обороты'; en = 'Balance and turnovers'; pl = 'Saldo i obroty';es_ES = 'Saldo y facturación';es_CO = 'Saldo y facturación';tr = 'Bakiye ve cirolar';it = 'Saldi e fatturati';de = 'Balance und Umsätze'"));
		Else
			ValuesForSelection.Add("Turnovers", NStr("ru = 'Обороты'; en = 'Turnovers'; pl = 'Obroty';es_ES = 'Movimientos';es_CO = 'Movimientos';tr = 'Cirolar';it = 'Fatturati';de = 'Umsätze'"));
		EndIf;
	ElsIf MetadataObjectType = "InformationRegisters" Then 
		If Metadata[MetadataObjectType][MetadataObjectName].InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		Else
			ValuesForSelection.Add("SliceLast", NStr("ru = 'Срез последних'; en = 'Slice of the last ones'; pl = 'Przekrój ostatnich';es_ES = 'Corte de últimos';es_CO = 'Corte de últimos';tr = 'Son olanların kesiti';it = 'Fette degli ultimi';de = 'Schnitt vom Letzten'"));
			ValuesForSelection.Add("SliceFirst",    NStr("ru = 'Срез первых'; en = 'Slice of the first ones'; pl = 'Przekrój pierwszych';es_ES = 'Corte de primeros';es_CO = 'Corte de primeros';tr = 'Birincilerin kesiti';it = 'Fetta dei primi';de = 'Schnitt vom Ersten'"));
		EndIf;
	ElsIf MetadataObjectType = "CalculationRegisters" Then 
		If Metadata[MetadataObjectType][MetadataObjectName].ActionPeriod Then
			ValuesForSelection.Add("ScheduleData",             NStr("ru = 'Данные графика'; en = 'Chart data'; pl = 'Dane harmonogramu';es_ES = 'Datos del gráfico';es_CO = 'Datos del gráfico';tr = 'Grafik verileri';it = 'Dati grafico';de = 'Grafikdaten'"));
			ValuesForSelection.Add("ActualActionPeriod", NStr("ru = 'Фактический период действия'; en = 'Actual validity period'; pl = 'Rzeczywisty okres obowiązywania';es_ES = 'Período de acción actual';es_CO = 'Período de acción actual';tr = 'Fiili geçerlilik dönemi';it = 'Periodo di validità effettivo';de = 'Tatsächlicher Gültigkeitszeitraum'"));
		EndIf;
	ElsIf MetadataObjectType = "ChartsOfCalculationTypes" Then
		MetadataObject = Metadata[MetadataObjectType][MetadataObjectName];
		If MetadataObject.DependenceOnCalculationTypes
			<> Metadata.ObjectProperties.ChartOfCalculationTypesBaseUse.DontUse Then 
			
			ValuesForSelection.Add("BaseCalculationTypes", NStr("ru = 'Базовые типы расчета'; en = 'Base calculation types'; pl = 'Podstawowe rodzaje obliczeń';es_ES = 'Tipos de liquidaciones básicos';es_CO = 'Tipos de liquidaciones básicos';tr = 'Temel hesaplama türleri';it = 'Tipi di calcolo di base';de = 'Grundlegende Berechnungsarten'"));
		EndIf;
		
		ValuesForSelection.Add("LeadingCalculationTypes", NStr("ru = 'Ведущие виды расчета'; en = 'Leading calculation kinds'; pl = 'Czołowe rodzaje obliczeń';es_ES = 'Tipos de liquidaciones principales';es_CO = 'Tipos de liquidaciones principales';tr = 'En önemli hesaplama türleri';it = 'Tipologie di calcolo principale';de = 'Führende Berechnungsarten'"));
		
		If MetadataObject.ActionPeriodUse Then 
			ValuesForSelection.Add("DisplacingCalculationTypes", NStr("ru = 'Вытесняющие виды расчета'; en = 'Preemptive calculation kinds'; pl = 'Wypierające rodzaje obliczeń';es_ES = 'Tipos de liquidaciones desplazados';es_CO = 'Tipos de liquidaciones desplazados';tr = 'Yerinden çıkaran hesaplama türleri';it = 'Tipologie di calcolo preventivo';de = 'Vorhersage von Berechnungsarten'"));
		EndIf;
	ElsIf MetadataObjectType = "AccountingRegisters" Then
		ValuesForSelection.Add("BalanceAndTurnovers",   NStr("ru = 'Остатки и обороты'; en = 'Balance and turnovers'; pl = 'Saldo i obroty';es_ES = 'Saldo y facturación';es_CO = 'Saldo y facturación';tr = 'Bakiye ve cirolar';it = 'Saldi e fatturati';de = 'Balance und Umsätze'"));
		ValuesForSelection.Add("Balance",           NStr("ru = 'Остатки'; en = 'Balance'; pl = 'Saldo';es_ES = 'Saldo';es_CO = 'Saldo';tr = 'Bakiye';it = 'Saldo';de = 'Saldo'"));
		ValuesForSelection.Add("Turnovers",           NStr("ru = 'Обороты'; en = 'Turnovers'; pl = 'Obroty';es_ES = 'Movimientos';es_CO = 'Movimientos';tr = 'Cirolar';it = 'Fatturati';de = 'Umsätze'"));
		ValuesForSelection.Add("DrCrTurnovers",       NStr("ru = 'Обороты Дт/Кт'; en = 'Dr/Cr turnovers'; pl = 'Obroty Wn/Ma';es_ES = 'Movimientos D/H';es_CO = 'Movimientos D/H';tr = 'Borç/Alacak cirosu';it = 'Fatturati Deb/ Cred';de = 'Soll/Haben - Umsätze'"));
		ValuesForSelection.Add("RecordsWithExtDimensions", NStr("ru = 'Движения с субконто'; en = 'Movements with extra dimension'; pl = 'Ruch z subkonto';es_ES = 'Registros con cuentas analíticas';es_CO = 'Registros con cuentas analíticas';tr = 'Alt hesap hareketleri';it = 'Movimenti con dimensioni extra';de = 'Subkonto-Bewegungen'"));
	ElsIf IsImportedSchema Then
		ValuesForSelection.Clear();
	EndIf;
	
	Return ValuesForSelection;
	
EndFunction

Function HasMetadataTypeObjects(MetadataType)
	
	For each Object In MetadataType Do
		If Common.MetadataObjectAvailableByFunctionalOptions(Object)
			AND AccessRight("Read", Object) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function DefaultMetadataObjectType()
	
	ValuesForSelection = AvailableMetadataObjectsTypes();
	
	If ValuesForSelection.FindByValue("AccumulationRegisters") <> Undefined Then
		Return "AccumulationRegisters";
	Else
		Return ValuesForSelection[0].Value;
	EndIf;
	
EndFunction

Function DefaultMetadataObjectName(DCSettings, MetadataObjectType)
	
	ValuesForSelection = AvailableMetadataObjects(DCSettings, MetadataObjectType);
	
	IsImportedSchema = DCSettings.AdditionalProperties.Property("DataCompositionSchema");
	If Not IsImportedSchema AND ValuesForSelection.Count() > 0 Then
		DefaultValue = ValuesForSelection[0].Value;
	EndIf;
	
	Return DefaultValue;
	
EndFunction

Function DefaultTableName(DCSettings, MetadataObjectType, MetadataObjectName)
	
	ValuesForSelection = AvailableTables(DCSettings, MetadataObjectType, MetadataObjectName);
	
	IsImportedSchema = DCSettings.AdditionalProperties.Property("DataCompositionSchema");
	If Not IsImportedSchema AND ValuesForSelection.Count() > 0 Then
		DefaultValue = ValuesForSelection[0].Value;
	EndIf;
	
	Return DefaultValue;
	
EndFunction

Procedure AddTotals(ReportParameters, DataCompositionSchema)
	
	If ReportParameters.MetadataObjectType = "AccumulationRegisters" 
		OR ReportParameters.MetadataObjectType = "InformationRegisters" 
		OR ReportParameters.MetadataObjectType = "AccountingRegisters" 
		OR ReportParameters.MetadataObjectType = "CalculationRegisters" Then
		
		AddRegisterTotals(ReportParameters, DataCompositionSchema);
		
	ElsIf ReportParameters.MetadataObjectType = "Documents" 
		OR ReportParameters.MetadataObjectType = "Catalogs" 
		OR ReportParameters.MetadataObjectType = "BusinessProcesses"
		OR ReportParameters.MetadataObjectType = "Tasks" Then
		
		AddObjectTotals(ReportParameters, DataCompositionSchema);
	EndIf;
	
EndProcedure

Procedure AddObjectTotals(Val ReportParameters, Val DataCompositionSchema)
	
	MetadataObject = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
	If ReportParameters.TableName <> "" Then
		TabularSection = MetadataObject.TabularSections.Find(ReportParameters.TableName);
		If TabularSection <> Undefined Then 
			MetadataObject = TabularSection;
		EndIf;
	EndIf;
	
	// Add totals by numeric attributes
	For each Attribute In MetadataObject.Attributes Do
		AddDataSetField(DataCompositionSchema.DataSets[0], Attribute.Name, Attribute.Synonym);
		If Attribute.Type.ContainsType(Type("Number")) Then
			AddTotalField(DataCompositionSchema, Attribute.Name);
		EndIf;
	EndDo;

EndProcedure

Procedure AddRegisterTotals(Val ReportParameters, Val DataCompositionSchema)
	
	MetadataObject = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName]; 
	
	// Add dimensions
	For each Dimension In MetadataObject.Dimensions Do
		AddDataSetField(DataCompositionSchema.DataSets[0], Dimension.Name, Dimension.Synonym);
	EndDo;
	
	// Add attributes
	If IsBlankString(ReportParameters.TableName) Then
		For each Attribute In MetadataObject.Attributes Do
			AddDataSetField(DataCompositionSchema.DataSets[0], Attribute.Name, Attribute.Synonym);
		EndDo;
	EndIf;
	
	// Add period fields
	If ReportParameters.TableName = "BalanceAndTurnovers" 
		OR ReportParameters.TableName = "Turnovers" 
		OR ReportParameters.MetadataObjectType = "AccountingRegisters" AND ReportParameters.TableName = ""Then
		AddPeriodFieldsInDataSet(DataCompositionSchema.DataSets[0]);
	EndIf;
	
	// For accounting registers, setting up roles is important.
	If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
		
		AccountField = AddDataSetField(DataCompositionSchema.DataSets[0], "Account", NStr("ru = 'Учетная запись'; en = 'Account'; pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Rechnung'"));
		AccountField.Role.AccountTypeExpression = "Account.Type";
		AccountField.Role.Account = True;
		
		For ExtDimensionNumber = 1 To 3 Do
			ExtDimensionField = AddDataSetField(DataCompositionSchema.DataSets[0], "ExtDimensions" + ExtDimensionNumber, NStr("ru = 'ExtDimension'; en = 'ExtDimension'; pl = 'ExtDimension';es_ES = 'Cuenta analítica';es_CO = 'Cuenta analítica';tr = 'ExtDimension';it = 'ExtDimension';de = 'Subkonto'") + " " + ExtDimensionNumber);
			ExtDimensionField.Role.Dimension = True;
			ExtDimensionField.Role.IgnoreNULLValues = True;
		EndDo;
		
	EndIf;
	
	// Add resources
	For each Resource In MetadataObject.Resources Do
		If ReportParameters.TableName = "Turnovers" Then
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Turnover", Resource.Synonym);
			AddTotalField(DataCompositionSchema, Resource.Name + "Turnover");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("ru = 'оборот Дт'; en = 'Dr turnover'; pl = 'Obrót Dt';es_ES = 'movimiento D';es_CO = 'movimiento D';tr = 'ciro Borç';it = 'Deb fatturato';de = 'Soll-Umsatz'"), Resource.Name + "TurnoverDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverDr");
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("ru = 'оборот Кт'; en = 'Cr turnover'; pl = 'obrót Ct';es_ES = 'movimiento H';es_CO = 'movimiento H';tr = 'ciro Alacak';it = 'Cred fatturato';de = 'Haben-Umsatz'"), Resource.Name + "TurnoverCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverCr");
				
				If NOT Resource.Balance Then
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalancedTurnover", Resource.Synonym + " " + NStr("ru = 'кор. оборот'; en = 'corr. turnover'; pl = 'kor. obrót';es_ES = 'movimiento corresponsal';es_CO = 'movimiento corresponsal';tr = 'muh.ciro';it = 'Fatturato corr.';de = 'Kor. Umsatz'"), Resource.Name + "BalancedTurnover");
					AddTotalField(DataCompositionSchema, Resource.Name + "BalancedTurnover");
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalancedTurnoverDr", Resource.Synonym + " " + NStr("ru = 'кор. оборот Дт'; en = 'Dr corr. turnover'; pl = 'Kor. obrót Wn';es_ES = 'movimiento corresponsal D';es_CO = 'movimiento corresponsal D';tr = 'muh. ciro Borç';it = 'Deb fatturato corr.';de = 'Kor. Soll-Umsatz'"), Resource.Name + "BalancedTurnoverDr");
					AddTotalField(DataCompositionSchema, Resource.Name + "BalancedTurnoverDr");
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalancedTurnoverCr", Resource.Synonym + " " + NStr("ru = 'кор. оборот Кт'; en = 'Cr corr. turnover'; pl = 'kor. obrót Ma';es_ES = 'movimiento corresponsal H';es_CO = 'movimiento corresponsal H';tr = 'muh. ciro Alacak';it = 'Cred fatturato corr.';de = 'Kor. Haben-Umsatz'"), Resource.Name + "BalancedTurnoverCr");
					AddTotalField(DataCompositionSchema, Resource.Name + "BalancedTurnoverCr");
				EndIf;
			EndIf;
			
		ElsIf ReportParameters.TableName = "DrCrTurnovers" Then
			
			If Resource.Balance Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Turnover", Resource.Synonym);
				AddTotalField(DataCompositionSchema, Resource.Name + "Turnover");
			Else
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("ru = 'оборот Дт'; en = 'Dr turnover'; pl = 'Obrót Dt';es_ES = 'movimiento D';es_CO = 'movimiento D';tr = 'ciro Borç';it = 'Deb fatturato';de = 'Soll-Umsatz'"), Resource.Name + "TurnoverDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverDr");
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("ru = 'оборот Кт'; en = 'Cr turnover'; pl = 'obrót Ct';es_ES = 'movimiento H';es_CO = 'movimiento H';tr = 'ciro Alacak';it = 'Cred fatturato';de = 'Haben-Umsatz'"), Resource.Name + "TurnoverCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverCr");
			EndIf;
			
		ElsIf ReportParameters.TableName = "RecordsWithExtDimensions" Then
			
			If Resource.Balance Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
				AddTotalField(DataCompositionSchema, Resource.Name);
			Else
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Dr", Resource.Synonym + " " + NStr("ru = 'Дт'; en = 'Dr'; pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Deb';de = 'Soll'"), Resource.Name + "Dr");
				AddTotalField(DataCompositionSchema, Resource.Name + "Dr");
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Cr", Resource.Synonym + " " + NStr("ru = 'Кт'; en = 'Cr'; pl = 'Ma';es_ES = 'Correspondencia';es_CO = 'Correspondencia';tr = 'Cr';it = 'Cred';de = 'Haben'"), Resource.Name + "Cr");
				AddTotalField(DataCompositionSchema, Resource.Name + "Cr");
			EndIf;
			
		ElsIf ReportParameters.TableName = "BalanceAndTurnovers" Then
			
			SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningBalance", Resource.Synonym + " " + NStr("ru = 'нач. остаток'; en = 'open. balance'; pl = 'pocz. zapasy';es_ES = 'saldo inicial';es_CO = 'saldo inicial';tr = 'ilk bakiye';it = 'bilancio di apertura';de = 'Anf. Rest'"), Resource.Name + "OpeningBalance");
			AddTotalField(DataCompositionSchema, Resource.Name + "OpeningBalance");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				SetField.Role.AccountField = "Account";
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningBalanceDr", Resource.Synonym + " " + NStr("ru = 'нач. остаток Дт'; en = 'open. balance Dr'; pl = 'saldo początkowe Wn';es_ES = 'saldo inicial D';es_CO = 'saldo inicial D';tr = 'ilk bakiye Borç';it = 'Saldo di apertura Deb';de = 'Soll-Anfangssaldo'"), Resource.Name + "OpeningBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Debit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningBalanceCr", Resource.Synonym + " " + NStr("ru = 'нач. остаток Кт'; en = 'open. balance Cr'; pl = 'pocz. zapasy Ma';es_ES = 'saldo inicial H';es_CO = 'saldo inicial H';tr = 'ilk bakiye Alacak';it = 'Saldo di apertura Cred';de = 'Haben-Anfangssaldo'"), Resource.Name + "OpeningBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Credit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningBalanceCr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningSplittedBalanceDr", Resource.Synonym + " " + NStr("ru = 'нач. развернутый остаток Дт'; en = 'start detailed balance Dr'; pl = 'szczegół. saldo początkowe Wn';es_ES = 'saldo inicial expandido D';es_CO = 'saldo inicial expandido D';tr = 'ilk geniş bakiye Alacak';it = 'Avvia bilancio dettagliato Deb';de = 'Anfang entfaltetes Soll-Saldo'"), Resource.Name + "OpeningSplittedBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "DetailedBalance" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningSplittedBalanceDr");
				
				SetField =AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningSplittedBalanceCr", Resource.Synonym + " " + NStr("ru = 'нач. развернутый остаток Кт'; en = 'start detailed balance Cr'; pl = 'pocz. szczegół. zapasy Ma';es_ES = 'saldo inicial expandido H';es_CO = 'saldo inicial expandido H';tr = 'ilk geniş bakiye Borç';it = 'Avvia bilancio dettagliato Cred';de = 'Entfalteter Haben-Anfangssaldo'"), Resource.Name + "OpeningSplittedBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "DetailedBalance" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningSplittedBalanceCr");
			EndIf;
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Turnover", Resource.Synonym + " " + NStr("ru = 'оборот'; en = 'turnover'; pl = 'obrót';es_ES = 'movimiento';es_CO = 'movimiento';tr = 'ciro';it = 'fatturato';de = 'Umsatz'"), Resource.Name + "Turnover");
			AddTotalField(DataCompositionSchema, Resource.Name + "Turnover");
			
			If ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Receipt", Resource.Synonym + " " + NStr("ru = 'приход'; en = 'receipt'; pl = 'paragon';es_ES = 'recibo';es_CO = 'recibo';tr = 'gelir';it = 'entrata';de = 'Einnahme'"), Resource.Name + "Receipt");
				AddTotalField(DataCompositionSchema, Resource.Name + "Receipt");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Expense", Resource.Synonym + " " + NStr("ru = 'расход'; en = 'expense'; pl = 'rozchód';es_ES = 'gasto';es_CO = 'gasto';tr = 'Masraf';it = 'uscita';de = 'Aufwand'"), Resource.Name + "Expense");
				AddTotalField(DataCompositionSchema, Resource.Name + "Expense");
			ElsIf ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("ru = 'оборот Дт'; en = 'Dr turnover'; pl = 'Obrót Dt';es_ES = 'movimiento D';es_CO = 'movimiento D';tr = 'ciro Borç';it = 'Deb fatturato';de = 'Soll-Umsatz'"), Resource.Name + "TurnoverDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverDr");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("ru = 'оборот Кт'; en = 'Cr turnover'; pl = 'obrót Ct';es_ES = 'movimiento H';es_CO = 'movimiento H';tr = 'ciro Alacak';it = 'Cred fatturato';de = 'Haben-Umsatz'"), Resource.Name + "TurnoverCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverCr");
			EndIf;
			
			SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingBalance", Resource.Synonym + " " + NStr("ru = 'кон. остаток'; en = 'clos. balance'; pl = 'koń. zapasy';es_ES = 'saldo final';es_CO = 'saldo final';tr = 'son bakiye';it = 'saldo di chiusura';de = 'End. Balance'"), Resource.Name + "ClosingBalance");
			AddTotalField(DataCompositionSchema, Resource.Name + "ClosingBalance");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingBalanceDr", Resource.Synonym + " " + NStr("ru = 'кон. остаток Дт'; en = 'Dr clos. balance'; pl = 'Sal. koń Wn';es_ES = 'saldo final D';es_CO = 'saldo final D';tr = 'son bakiye Borç';it = 'Saldo di chiusura Deb';de = 'Soll-Abschlusssaldo'"), Resource.Name + "ClosingBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Debit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingBalanceCr", Resource.Synonym + " " + NStr("ru = 'кон. остаток Кт'; en = 'Cr clos. balance'; pl = 'koń. zapasy Ma';es_ES = 'saldo final H';es_CO = 'saldo final H';tr = 'son bakiye Alacak';it = 'Saldo di chiusura Cred';de = 'Haben-Abschlusssaldo'"), Resource.Name + "ClosingBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Credit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingBalanceCr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingSplittedBalanceDr", Resource.Synonym + " " + NStr("ru = 'кон. развернутый остаток Дт'; en = 'closing detailed balance Dr'; pl = 'szczegół saldo końcowe Wn';es_ES = 'saldo final expandido D';es_CO = 'saldo final expandido D';tr = 'son geniş bakiye Borç';it = 'chiusura bilancio dettagliato Deb';de = 'Entfaltetes Soll-Abschlusssaldo'"), Resource.Name + "ClosingSplittedBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "DetailedBalance" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingSplittedBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingSplittedBalanceCr", Resource.Synonym + " " + NStr("ru = 'кон. развернутый остаток Кт'; en = 'closing detailed balance Cr'; pl = 'kon. szczegół. zapasy Ma';es_ES = 'saldo final expandido H';es_CO = 'saldo final expandido H';tr = 'son geniş bakiye Alacak';it = 'chiusura bilancio dettagliato Cred';de = 'Entfalteter Haben-Abschlusssaldo'"), Resource.Name + "ClosingSplittedBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "DetailedBalance" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingSplittedBalanceCr");
			EndIf;
			
		ElsIf ReportParameters.TableName = "Balance" Then
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Balance", Resource.Synonym + " " + NStr("ru = 'остаток'; en = 'balance'; pl = 'saldo';es_ES = 'saldo';es_CO = 'saldo';tr = 'Bakiye';it = 'saldo';de = 'Balance'"), Resource.Name + "Balance");
			AddTotalField(DataCompositionSchema, Resource.Name + "Balance");
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalanceDr", Resource.Synonym + " " + NStr("ru = 'остаток Дт'; en = 'Dr balance'; pl = 'Saldo Wn';es_ES = 'saldo D';es_CO = 'saldo D';tr = 'bakiye Alacak';it = 'Deb saldo';de = 'Soll-Saldo'"), Resource.Name + "BalanceDr");
			AddTotalField(DataCompositionSchema, Resource.Name + "BalanceDr");
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalanceCr", Resource.Synonym + " " + NStr("ru = 'остаток Кт'; en = 'Cr balance'; pl = 'zapasy Ma';es_ES = 'saldo H';es_CO = 'saldo H';tr = 'bakiye Borç';it = 'Cred saldo';de = 'Haben-Saldo'"), Resource.Name + "BalanceCr");
			AddTotalField(DataCompositionSchema, Resource.Name + "BalanceCr");
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "DetailedBalanceDr", Resource.Synonym + " " + NStr("ru = 'развернутый остаток Дт'; en = 'detailed balance Dr'; pl = 'szczegół. zapasy Ma';es_ES = 'saldo expandido D';es_CO = 'saldo expandido D';tr = 'geniş bakiye Alacak';it = 'Saldo dettagliato Deb.';de = 'Entfaltetes Soll-Saldo'"), Resource.Name + "DetailedBalanceDr");
			AddTotalField(DataCompositionSchema, Resource.Name + "DetailedBalanceDr");
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "DetailedBalanceCr", Resource.Synonym + " " + NStr("ru = 'развернутый остаток Кт'; en = 'detailed balance Cr'; pl = 'szczegół. zapasy Ma';es_ES = 'saldo expandido H';es_CO = 'saldo expandido H';tr = 'geniş bakiye Borç';it = 'Saldo dettagliato Cred';de = 'Entfalteter Haben-Saldo'"), Resource.Name + "DetailedBalanceCr");
			AddTotalField(DataCompositionSchema, Resource.Name + "DetailedBalanceCr");
			
		ElsIf ReportParameters.MetadataObjectType = "InformationRegisters" Then
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
			If Resource.Type.ContainsType(Type("Number")) Then
				AddTotalField(DataCompositionSchema, Resource.Name);
			EndIf;
		ElsIf ReportParameters.TableName = "" Then
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				If Resource.Balance Then
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
					AddTotalField(DataCompositionSchema, Resource.Name);
				Else
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Dr", Resource.Synonym + " " + NStr("ru = 'Дт'; en = 'Dr'; pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Deb';de = 'Soll'"), Resource.Name + "Dr");
					AddTotalField(DataCompositionSchema, Resource.Name + "Dr");
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Cr", Resource.Synonym + " " + NStr("ru = 'Кт'; en = 'Cr'; pl = 'Ma';es_ES = 'Correspondencia';es_CO = 'Correspondencia';tr = 'Cr';it = 'Cred';de = 'Haben'"), Resource.Name + "Cr");
					AddTotalField(DataCompositionSchema, Resource.Name + "Cr");
				EndIf;
			Else
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
				AddTotalField(DataCompositionSchema, Resource.Name);
			EndIf;
			
		EndIf;
	EndDo;

EndProcedure

Function AddPeriodFieldsInDataSet(DataSet)
	
	PeriodsList = New ValueList;
	PeriodsList.Add("SecondPeriod",   NStr("ru = 'Период секунда'; en = 'Period second'; pl = 'Okres sekunda';es_ES = 'Período segundo';es_CO = 'Período segundo';tr = 'Dönem saniye';it = 'Periodo secondo';de = 'Periode Sekunde'"));
	PeriodsList.Add("MinutePeriod",    NStr("ru = 'Период минута'; en = 'Period minute'; pl = 'Okres minuta';es_ES = 'Período minuto';es_CO = 'Período minuto';tr = 'Dönem dakika';it = 'Periodo minuto';de = 'Periode Minute'"));
	PeriodsList.Add("HourPeriod",       NStr("ru = 'Период час'; en = 'Period hour'; pl = 'Okres godzina';es_ES = 'Período hora';es_CO = 'Período hora';tr = 'Dönem saat';it = 'Periodo ora';de = 'Periode Stunde'"));
	PeriodsList.Add("DayPeriod",      NStr("ru = 'Период день'; en = 'Period day'; pl = 'Okres dzień';es_ES = 'Período día';es_CO = 'Período día';tr = 'Dönem Gün';it = 'Periodo, giorno';de = 'Periode Tag'"));
	PeriodsList.Add("WeekPeriod",    NStr("ru = 'Период неделя'; en = 'Period week'; pl = 'Okres tydzień';es_ES = 'Período Semana';es_CO = 'Período Semana';tr = 'Dönem Hafta';it = 'Periodo settimana';de = 'Periode Woche'"));
	PeriodsList.Add("TenDaysPeriod",    NStr("ru = 'Период декада'; en = 'Period ten-day period'; pl = 'Okres dekada';es_ES = 'Período período de diez días';es_CO = 'Período período de diez días';tr = 'Dönem On gün';it = 'Periodo, decade';de = 'Periode Zehn-Tage-Zeitraum'"));
	PeriodsList.Add("MonthPeriod",     NStr("ru = 'Период месяц'; en = 'Period month'; pl = 'Okres miesiąc';es_ES = 'Período mes';es_CO = 'Período mes';tr = 'Dönem Ay';it = 'Periodo mese';de = 'Zeitraum Monat'"));
	PeriodsList.Add("QuarterPeriod",   NStr("ru = 'Период квартал'; en = 'Period quarter'; pl = 'Okres kwartał';es_ES = 'Período Trimestre';es_CO = 'Período Trimestre';tr = 'Dönem Çeyrek yıl';it = 'Periodo trimestre';de = 'Periode Quartal'"));
	PeriodsList.Add("HalfYearPeriod", NStr("ru = 'Период полугодие'; en = 'Period half-year'; pl = 'Okres półrocze';es_ES = 'Período medio año';es_CO = 'Período medio año';tr = 'Dönem yarıyıl';it = 'Periodo semestre';de = 'Halbjahreszeitraum'"));
	PeriodsList.Add("YearPeriod",       NStr("ru = 'Период год'; en = 'Period year'; pl = 'Okres rok';es_ES = 'Período Año';es_CO = 'Período Año';tr = 'Dönem Yıl';it = 'Periodo anno';de = 'Periode Jahr'"));
	
	FolderName = "Periods";
	DataSetFieldsList = New ValueList;
	DataSetFieldsFolder = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetFieldFolder"));
	DataSetFieldsFolder.Title   = FolderName;
	DataSetFieldsFolder.DataPath = FolderName;
	
	PeriodType = DataCompositionPeriodType.Main;
	
	For each Period In PeriodsList Do
		DataSetField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
		DataSetField.Field        = Period.Value;
		DataSetField.Title   = Period.Presentation;
		DataSetField.DataPath = FolderName + "." + Period.Value;
		DataSetField.Role.PeriodType = PeriodType;
		DataSetField.Role.PeriodNumber = PeriodsList.IndexOf(Period);
		DataSetFieldsList.Add(DataSetField);
		PeriodType = DataCompositionPeriodType.Additional;
	EndDo;
	
	Return DataSetFieldsList;
	
EndFunction

// Add field to data set.
Function AddDataSetField(DataSet, Field, Header, DataPath = Undefined)
	
	If DataPath = Undefined Then
		DataPath = Field;
	EndIf;
	
	DataSetField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	DataSetField.Field        = Field;
	DataSetField.Title   = Header;
	DataSetField.DataPath = DataPath;
	Return DataSetField;
	
EndFunction

// Add total field to data composition schema. If the Expression parameter is not specified, Sum(PathToData) is used.
Function AddTotalField(DataCompositionSchema, DataPath, Expression = Undefined)
	
	If Expression = Undefined Then
		Expression = "SUM(" + DataPath + ")";
	EndIf;
	
	TotalField = DataCompositionSchema.TotalFields.Add();
	TotalField.DataPath = DataPath;
	TotalField.Expression = Expression;
	Return TotalField;
	
EndFunction

Procedure AddIndicators(ReportParameters, DCSettings)
	
	If ReportParameters.TableName = "BalanceAndTurnovers" Then
		SelectedFieldsOpeningBalance = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
		SelectedFieldsOpeningBalance.Title = NStr("ru = 'Нач. остаток'; en = 'Open. balance'; pl = 'Pocz. zapasy';es_ES = 'Saldo inicial';es_CO = 'Saldo inicial';tr = 'İlk bakiye';it = 'Bilancio di apertura';de = 'Anf. rest'");
		SelectedFieldsOpeningBalance.Placement = DataCompositionFieldPlacement.Horizontally;
		If ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
			SelectedFieldsReceipt = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
			SelectedFieldsReceipt.Title = NStr("ru = 'Приход'; en = 'Receipt'; pl = 'Paragon';es_ES = 'Recibo';es_CO = 'Recibo';tr = 'Gelir';it = 'Entrata';de = 'Erhalt'");
			SelectedFieldsReceipt.Placement = DataCompositionFieldPlacement.Horizontally;
			SelectedFieldsExpense = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
			SelectedFieldsExpense.Title = NStr("ru = 'Расход'; en = 'Expense'; pl = 'Koszt';es_ES = 'Gastos';es_CO = 'Gastos';tr = 'Masraf';it = 'Uscita';de = 'Aufwand'");
			SelectedFieldsExpense.Placement = DataCompositionFieldPlacement.Horizontally;
		ElsIf ReportParameters.MetadataObjectType = "AccountingRegisters" Then
			SelectedFieldsTurnovers = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
			SelectedFieldsTurnovers.Title = NStr("ru = 'Обороты'; en = 'Turnovers'; pl = 'Obroty';es_ES = 'Movimientos';es_CO = 'Movimientos';tr = 'Cirolar';it = 'Fatturati';de = 'Umsätze'");
			SelectedFieldsTurnovers.Placement = DataCompositionFieldPlacement.Horizontally;
		EndIf;
		SelectedFieldsClosingBalance = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
		SelectedFieldsClosingBalance.Title = NStr("ru = 'Кон. остаток'; en = 'Clos. balance'; pl = 'Koń. zapasy';es_ES = 'Saldo final';es_CO = 'Saldo final';tr = 'Son bakiye';it = 'Saldo di chiusura';de = 'End. balance'");
		SelectedFieldsClosingBalance.Placement = DataCompositionFieldPlacement.Horizontally;
	EndIf;
	
	MetadataObject = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
	If ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
		For Each Dimension In MetadataObject.Dimensions Do
			SelectedFields = DCSettings.Selection;
			ReportsClientServer.AddSelectedField(SelectedFields, Dimension.Name);
		EndDo;
		For Each Resource In MetadataObject.Resources Do
			SelectedFields = DCSettings.Selection;
			If ReportParameters.TableName = "Turnovers" Then
				ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "Turnover");
			ElsIf ReportParameters.TableName = "BalanceAndTurnovers" Then
				ReportsClientServer.AddSelectedField(SelectedFieldsOpeningBalance, Resource.Name + "OpeningBalance", Resource.Synonym);
				ReportsClientServer.AddSelectedField(SelectedFieldsReceipt, Resource.Name + "Receipt", Resource.Synonym);
				ReportsClientServer.AddSelectedField(SelectedFieldsExpense, Resource.Name + "Expense", Resource.Synonym);
				ReportsClientServer.AddSelectedField(SelectedFieldsClosingBalance, Resource.Name + "ClosingBalance", Resource.Synonym);
			ElsIf ReportParameters.TableName = "" Then
				ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name);
			EndIf;
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "CalculationRegisters" Then
		For Each Dimension In MetadataObject.Dimensions Do
			SelectedFields = DCSettings.Selection;
			ReportsClientServer.AddSelectedField(SelectedFields, Dimension.Name);
		EndDo;
		For Each Resource In MetadataObject.Resources Do
			SelectedFields = DCSettings.Selection;
			ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name);
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "InformationRegisters" Then
		For Each Dimension In MetadataObject.Dimensions Do
			SelectedFields = DCSettings.Selection;
			ReportsClientServer.AddSelectedField(SelectedFields, Dimension.Name);
		EndDo;
		For Each Resource In MetadataObject.Resources Do
			SelectedFields = DCSettings.Selection;
			ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name);
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "AccountingRegisters" Then
		For Each Resource In MetadataObject.Resources Do
			SelectedFields = DCSettings.Selection;
			If ReportParameters.TableName = "Turnovers" Then
				ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("ru = 'оборот Дт'; en = 'Dr turnover'; pl = 'Obrót Dt';es_ES = 'movimiento D';es_CO = 'movimiento D';tr = 'ciro Borç';it = 'Deb fatturato';de = 'Soll-Umsatz'"));
				ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("ru = 'оборот Кт'; en = 'Cr turnover'; pl = 'obrót Ct';es_ES = 'movimiento H';es_CO = 'movimiento H';tr = 'ciro Alacak';it = 'Cred fatturato';de = 'Haben-Umsatz'"));
			ElsIf ReportParameters.TableName = "DrCrTurnovers" Then
				If Resource.Balance Then
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "Turnover", Resource.Synonym + " " + NStr("ru = 'оборот'; en = 'turnover'; pl = 'obrót';es_ES = 'movimiento';es_CO = 'movimiento';tr = 'ciro';it = 'fatturato';de = 'Umsatz'"));
				Else
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("ru = 'оборот Дт'; en = 'Dr turnover'; pl = 'Obrót Dt';es_ES = 'movimiento D';es_CO = 'movimiento D';tr = 'ciro Borç';it = 'Deb fatturato';de = 'Soll-Umsatz'"));
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("ru = 'оборот Кт'; en = 'Cr turnover'; pl = 'obrót Ct';es_ES = 'movimiento H';es_CO = 'movimiento H';tr = 'ciro Alacak';it = 'Cred fatturato';de = 'Haben-Umsatz'"));
				EndIf;
			ElsIf ReportParameters.TableName = "Balance" Then
				ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "BalanceDr", Resource.Synonym + " " + NStr("ru = 'ост. Дт'; en = 'Dr bal.'; pl = 'Sal. Wn';es_ES = 'saldo D';es_CO = 'saldo D';tr = 'bakiye Borç';it = 'Dr bal.';de = 'Soll-Saldo'"));
				ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "BalanceCr", Resource.Synonym + " " + NStr("ru = 'ост. Кт'; en = 'Cr bal.'; pl = 'zap. Ma';es_ES = 'saldo H';es_CO = 'saldo H';tr = 'bakiye Alacak';it = 'Cr bal.';de = 'Haben-Saldo'"));
			ElsIf ReportParameters.TableName = "BalanceAndTurnovers" Then
				ReportsClientServer.AddSelectedField(SelectedFieldsOpeningBalance, Resource.Name + "OpeningBalanceDr", Resource.Synonym + " " + NStr("ru = 'нач. ост. Дт'; en = 'open. bal. Dr'; pl = 'sal. pocz. Wn';es_ES = 'saldo inicial D';es_CO = 'saldo inicial D';tr = 'ilk bakiye Borç';it = 'Saldo di apertura Deb';de = 'Soll-Anfangssaldo'"));
				ReportsClientServer.AddSelectedField(SelectedFieldsOpeningBalance, Resource.Name + "OpeningBalanceCr", Resource.Synonym + " " + NStr("ru = 'нач. ост. Кт'; en = 'open. bal. Cr'; pl = 'sal. pocz. Ma';es_ES = 'saldo inicial H';es_CO = 'saldo inicial H';tr = 'ilk bakiye Alacak';it = 'Saldo di apertura Cred';de = 'Haben-Anfangssaldo'"));
				ReportsClientServer.AddSelectedField(SelectedFieldsTurnovers, Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("ru = 'оборот Дт'; en = 'Dr turnover'; pl = 'Obrót Dt';es_ES = 'movimiento D';es_CO = 'movimiento D';tr = 'ciro Borç';it = 'Deb fatturato';de = 'Soll-Umsatz'"));
				ReportsClientServer.AddSelectedField(SelectedFieldsTurnovers, Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("ru = 'оборот Кт'; en = 'Cr turnover'; pl = 'obrót Ct';es_ES = 'movimiento H';es_CO = 'movimiento H';tr = 'ciro Alacak';it = 'Cred fatturato';de = 'Haben-Umsatz'"));
				ReportsClientServer.AddSelectedField(SelectedFieldsClosingBalance, Resource.Name + "ClosingBalanceDr", " " + Resource.Synonym + NStr("ru = 'кон. ост. Дт'; en = 'Dr clos. bal.'; pl = 'Sal. koń. Wn.';es_ES = 'saldo final D';es_CO = 'saldo final D';tr = 'son bakiye Borç';it = 'Saldo di chiusura Deb.';de = 'Soll-Abschlusssaldo'"));
				ReportsClientServer.AddSelectedField(SelectedFieldsClosingBalance, Resource.Name + "ClosingBalanceCr", " " + Resource.Synonym + NStr("ru = 'кон. ост. Кт'; en = 'Cr clos. bal.'; pl = 'kon. zap. Ma';es_ES = 'saldo final H';es_CO = 'saldo final H';tr = 'son bakiye Alacak';it = 'Saldo di chiusura Cred.';de = 'Haben-Abschlusssaldo'"));
			ElsIf ReportParameters.TableName = "RecordsWithExtDimensions" Then
				If Resource.Balance Then
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name, Resource.Synonym);
				Else
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "Dr", Resource.Synonym + " " + NStr("ru = 'Дт'; en = 'Dr'; pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Deb';de = 'Soll'"));
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "Cr", Resource.Synonym + " " + NStr("ru = 'Кт'; en = 'Cr'; pl = 'Ma';es_ES = 'Correspondencia';es_CO = 'Correspondencia';tr = 'Cr';it = 'Cred';de = 'Haben'"));
				EndIf;
			ElsIf ReportParameters.TableName = "" Then
				If Resource.Balance Then
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name, Resource.Synonym);
				Else
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "Dr", Resource.Synonym + " " + NStr("ru = 'Дт'; en = 'Dr'; pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Deb';de = 'Soll'"));
					ReportsClientServer.AddSelectedField(SelectedFields, Resource.Name + "Cr", Resource.Synonym + " " + NStr("ru = 'Кт'; en = 'Cr'; pl = 'Ma';es_ES = 'Correspondencia';es_CO = 'Correspondencia';tr = 'Cr';it = 'Cred';de = 'Haben'"));
				EndIf;
			EndIf;
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "Documents" 
		OR ReportParameters.MetadataObjectType = "Tasks"
		OR ReportParameters.MetadataObjectType = "BusinessProcesses"
		OR ReportParameters.MetadataObjectType = "Catalogs" Then
		If ReportParameters.TableName <> "" Then
			MetadataObject = MetadataObject.TabularSections[ReportParameters.TableName];
		EndIf;
		SelectedFields = DCSettings.Selection;
		ReportsClientServer.AddSelectedField(SelectedFields, "Ref");
		For each Attribute In MetadataObject.Attributes Do
			ReportsClientServer.AddSelectedField(SelectedFields, Attribute.Name);
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "ChartsOfCalculationTypes" Then
		If ReportParameters.TableName = "" Then
			For each Attribute In MetadataObject.Attributes Do
				SelectedFields = DCSettings.Selection;
				ReportsClientServer.AddSelectedField(SelectedFields, Attribute.Name);
			EndDo;
		Else
			For each Attribute In MetadataObject.StandardAttributes Do
				SelectedFields = DCSettings.Selection;
				ReportsClientServer.AddSelectedField(SelectedFields, Attribute.Name);
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

// Generates the structure of data composition settings
//
// Parameters:
//  ReportParameters - Structure - a description of a metadata object that is a data source
//  Schema - DataCompositionSchema - main schema of report data composition
//  Settings - DataCompositionSettings - settings whose structure is being generated.
//
Procedure GenerateStructure(ReportParameters, Schema, Settings)
	Settings.Structure.Clear();
	
	Structure = Settings.Structure.Add(Type("DataCompositionGroup"));
	
	FieldsTypes = StrSplit("Dimensions@Resources", "@", False);
	
	SourcesFieldsTypes = New Map();
	SourcesFieldsTypes.Insert("InformationRegisters", FieldsTypes);
	SourcesFieldsTypes.Insert("AccumulationRegisters", FieldsTypes);
	SourcesFieldsTypes.Insert("AccountingRegisters", FieldsTypes);
	SourcesFieldsTypes.Insert("CalculationRegisters", FieldsTypes);
	
	SourceFieldsTypes = SourcesFieldsTypes[ReportParameters.MetadataObjectType];
	If SourceFieldsTypes <> Undefined Then 
		SpecifyFieldsSuffixes = ReportParameters.MetadataObjectType = "AccountingRegisters"
			AND (ReportParameters.TableName = ""
				Or ReportParameters.TableName = "DrCrTurnovers"
				Or ReportParameters.TableName = "RecordsWithExtDimensions");
		
		For Each SourceFieldsType In SourceFieldsTypes Do 
			GroupFields = Structure.GroupFields.Items;
			
			SourceMetadata = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
			For Each FieldMetadata In SourceMetadata[SourceFieldsType] Do
				If ReportParameters.MetadataObjectType = "AccountingRegisters"
					AND FieldMetadata.AccountingFlag <> Undefined Then 
					Continue;
				EndIf;
				
				If SourceFieldsType = "Resources"
					AND FieldMetadata.Type.ContainsType(Type("Number")) Then 
					Continue;
				EndIf;
				
				If SpecifyFieldsSuffixes
					AND Not FieldMetadata.Balance Then 
					FieldsSuffixes = StrSplit("Dr@Cr", "@", False);
				Else
					FieldsSuffixes = StrSplit("", "@");
				EndIf;
				
				For Each Suffix In FieldsSuffixes Do 
					GroupField = GroupFields.Add(Type("DataCompositionGroupField"));
					GroupField.Field = New DataCompositionField(FieldMetadata.Name + Suffix);
					GroupField.Use = True;
				EndDo;
			EndDo;
		EndDo;
	EndIf;
	
	Structure.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	Structure.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with a standard schema set in user settings.

Function ReportParameters(Settings, UserSettings) Export
	ReportParameters = New Structure(
		"Period, DataSource, MetadataObjectType, FullMetadataObjectName, MetadataObjectName, TableName");
	ReportParameters.Insert("ClearStructure", False);
	
	GetParametersFromUserSettings(ReportParameters, UserSettings, Settings.AdditionalProperties);
	GetParametersFromSettings(ReportParameters, Settings);
	
	// If option settings contain a parameter with a non-relevant name, the name will be updated.
	ReportParameters.Delete("FullMetadataObjectName");
	
	DataParameters = Settings.DataParameters.Items;
	ObsoleteParameter = DataParameters.Find("FullMetadataObjectName");
	If ObsoleteParameter <> Undefined Then 
		DataParameters.Delete(ObsoleteParameter);
	EndIf;
	
	CastToDataSource(ReportParameters, Settings);
	
	// Filling with default values.
	If Not ValueIsFilled(ReportParameters.MetadataObjectType) Then
		ReportParameters.MetadataObjectType = DefaultMetadataObjectType();
		ReportParameters.ClearStructure = True;
	EndIf;
	
	If Not ValueIsFilled(ReportParameters.MetadataObjectName) Then
		ReportParameters.MetadataObjectName = DefaultMetadataObjectName(
			Settings, ReportParameters.MetadataObjectType);
		ReportParameters.ClearStructure = True;
	EndIf;
	
	If ReportParameters.ClearStructure Then 
		CastToDataSource(ReportParameters, Settings);
	EndIf;
	
	AvailableTables = AvailableTables(
		Settings, ReportParameters.MetadataObjectType, ReportParameters.MetadataObjectName);
	
	If ReportParameters.TableName = Undefined
		Or AvailableTables.FindByValue(ReportParameters.TableName) = Undefined Then
		ReportParameters.TableName = DefaultTableName(
			Settings, ReportParameters.MetadataObjectType, ReportParameters.MetadataObjectName);
		ReportParameters.ClearStructure = True;
	EndIf;
	
	Return ReportParameters;
EndFunction

// Gets parameters that affect the building of the DCS data set query from user settings.
//
// Parameters:
//  Parameters - Structure - see ReportParameters() 
//  Settings - DataCompositionUserSettings - current user settings of data composition.
//
Procedure GetParametersFromUserSettings(Parameters, Settings, AdditionalProperties)
	If Not AdditionalProperties.Property("ReportInitialized")
		Or TypeOf(Settings) <> Type("DataCompositionUserSettings") Then 
		Return;
	EndIf;
	
	For Each SettingItem In Settings.Items Do
		If TypeOf(SettingItem) <> Type("DataCompositionSettingsParameterValue") Then
			Continue;
		EndIf;
		
		ParameterName = String(SettingItem.Parameter);
		If Parameters.Property(ParameterName)
			AND Parameters[ParameterName] = Undefined Then 
			Parameters[ParameterName] = SettingItem.Value;
		EndIf;
	EndDo;
	
	// If option settings contain a parameter with a non-relevant name, the name will be updated.
	If ValueIsFilled(Parameters.FullMetadataObjectName)
		AND Not ValueIsFilled(Parameters.MetadataObjectName) Then 
		Parameters.MetadataObjectName = Parameters.FullMetadataObjectName;
	EndIf;
EndProcedure

// Gets parameters that affect the building of the DCS data set query from settings.
//
// Parameters:
//  Parameters - Structure - see ReportParameters() 
//  Settings - DataCompositionSettings - current data composition settings.
//
Procedure GetParametersFromSettings(Parameters, Settings)
	DataParameters = Settings.DataParameters.Items;
	
	For Each Parameter In Parameters Do 
		SettingItem = DataParameters.Find(Parameter.Key);
		If SettingItem = Undefined Then 
			Continue;
		EndIf;
		
		If Parameter.Value = Undefined Then 
			Parameters[Parameter.Key] = SettingItem.Value;
		ElsIf SettingItem.Value <> Parameter.Value Then 
			SettingItem.Value = Parameter.Value;
			Settings.AdditionalProperties.Insert("ReportInitialized", False);
		EndIf;
	EndDo;
	
	// If option settings contain a parameter with a non-relevant name, the name will be updated.
	If ValueIsFilled(Parameters.FullMetadataObjectName)
		AND Not ValueIsFilled(Parameters.MetadataObjectName) Then 
		Parameters.MetadataObjectName = Parameters.FullMetadataObjectName;
	EndIf;
EndProcedure

// Sets the map of the MetadataObjectType, MetadataObjectName parameters with the DataSource 
//  parameter.
//
// Parameters:
//  Parameters - Structure - see ReportParameters() 
//  Settings - DataCompositionSettings - current data composition settings.
//
Procedure CastToDataSource(Parameters, Settings)
	If Not ValueIsFilled(Parameters.MetadataObjectType)
		Or Not ValueIsFilled(Parameters.MetadataObjectName) Then 
		Return;
	EndIf;
	
	MetadataObjectExists = CommonClientServer.HasAttributeOrObjectProperty(
		Metadata[Parameters.MetadataObjectType], Parameters.MetadataObjectName);
	
	If MetadataObjectExists Then 
		Parameters.DataSource = DataSource(Parameters.MetadataObjectType, Parameters.MetadataObjectName);
	ElsIf ValueIsFilled(Parameters.DataSource) Then 
		MetadataObject = Common.MetadataObjectByID(Parameters.DataSource);
		Parameters.MetadataObjectType = Common.BaseTypeNameByMetadataObject(MetadataObject);
		Parameters.MetadataObjectName = MetadataObject.Name;
		Parameters.TableName = Undefined;
	Else
		Parameters.MetadataObjectType = Undefined;
		Parameters.MetadataObjectName = Undefined;
		Parameters.TableName = Undefined;
	EndIf;
	
	// Matching data parameter value.
	DataParameters = Settings.DataParameters;
	
	SettingItem = DataParameters.Items.Find("DataSource");
	If SettingItem = Undefined Then 
		SettingItem = DataParameters.Items.Add();
		SettingItem.Parameter = New DataCompositionParameter("DataSource");
		SettingItem.Value = Parameters.DataSource;
		SettingItem.Use = True;
	Else
		DataParameters.SetParameterValue("DataSource", Parameters.DataSource);
	EndIf;
EndProcedure

Function GetStandardSchema(ReportParameters, DCSettings, NewDCUserSettings) Export
	
	DataCompositionSchema = GetTemplate("MainDataCompositionSchema");
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DataCompositionSchema.TotalFields.Clear();
	DataCompositionSchema.DataSets[0].Query = TextOfQueryByMetadata(ReportParameters);
	
	AddTotals(ReportParameters, DataCompositionSchema);
	
	// The Period parameter is not displayed for catalogs, calculation types plans and nonperiodical information registers.
	If ReportParameters.MetadataObjectType = "Catalogs"
		Or ReportParameters.MetadataObjectType = "ChartsOfCalculationTypes" 
		Or (ReportParameters.MetadataObjectType = "InformationRegisters"	
			AND Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName].InformationRegisterPeriodicity 
			= Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical) Then
		DataCompositionSchema.Parameters.Period.UseRestriction = True;
	EndIf;
	
	AvailableTables = AvailableTables(DCSettings, ReportParameters.MetadataObjectType, ReportParameters.MetadataObjectName);
	If AvailableTables.Count() <= 1 Then
		DataCompositionSchema.Parameters.TableName.UseRestriction = True;
	EndIf;
	
	Return DataCompositionSchema;
	
EndFunction

Procedure DCSettingsByStandardSchemaDefault(ReportObject, ReportParameters, DCSettings, NewDCUserSettings) Export
	
	If Not DCSettings.AdditionalProperties.Property("ReportInitialized")
		Or ((DCSettings.AdditionalProperties.Property("ReportInitialized")
			AND Not DCSettings.AdditionalProperties.ReportInitialized))
		Or ReportParameters.ClearStructure Then
		
		DCSchema = ReportObject.DataCompositionSchema;
		ReportObject.SettingsComposer.LoadSettings(DCSchema.DefaultSettings);
		
		AppearanceTemplate = AppearanceTemplate(DCSettings);
		
		DCSettings = ReportObject.SettingsComposer.Settings;
		
		DCSettings.Selection.Items.Clear();
		DCSettings.Structure.Clear();
		
		AddIndicators(ReportParameters, DCSettings);
		GenerateStructure(ReportParameters, DCSchema, DCSettings);
		
		DataParameters = DCSettings.DataParameters.Items;
		For Each ReportParameter In ReportParameters Do 
			DataParameter = DataParameters.Find(ReportParameter.Key);
			If DataParameter <> Undefined Then 
				DataParameter.Value = ReportParameter.Value;
			EndIf;
		EndDo;
		
		RestoreAppearanceTemplate(AppearanceTemplate, DCSettings);
		
		DCSettings.AdditionalProperties.Insert("ReportInitialized", True);
	EndIf;
	
EndProcedure

Function AppearanceTemplate(Settings)
	FoundParameter = Settings.OutputParameters.Items.Find("AppearanceTemplate");
	If FoundParameter.Value = "Main"
		Or FoundParameter.Value = "Main" Then
		Return Undefined;
	EndIf;
	
	Return FoundParameter.Value;
EndFunction

Procedure RestoreAppearanceTemplate(AppearanceTemplate, Settings)
	If AppearanceTemplate = Undefined Then 
		Return;
	EndIf;
	
	FoundParameter = Settings.OutputParameters.Items.Find("AppearanceTemplate");
	If FoundParameter.Value = "Main"
		Or FoundParameter.Value = "Main" Then
		
		FoundParameter.Value = AppearanceTemplate;
		FoundParameter.Use = True;
	EndIf;
	
	For Each StructureItem In Settings.Structure Do
		If TypeOf(StructureItem) <> Type("DataCompositionNestedObjectSettings") Then
			Continue;
		EndIf;
		
		FoundParameter = StructureItem.Settings.OutputParameters.Items.Find("AppearanceTemplate");
		If FoundParameter.Value = "Main" 
			Or FoundParameter.Value = "Main" Then
			
			FoundParameter.Value = AppearanceTemplate;
			FoundParameter.Use = True;
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with arbitrary schema from a file.

Function ExtractSchemaFromBinaryData(ImportedSchema) Export
	
	FullFileName = GetTempFileName();
	ImportedSchema.Write(FullFileName);
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FullFileName);
	DCSchema = XDTOSerializer.ReadXML(XMLReader, Type("DataCompositionSchema"));
	XMLReader.Close();
	XMLReader = Undefined;
	DeleteFiles(FullFileName);
	
	If DCSchema.DefaultSettings.AdditionalProperties.Property("DataCompositionSchema") Then
		DCSchema.DefaultSettings.AdditionalProperties.DataCompositionSchema = Undefined;
	EndIf;
	
	Return DCSchema;
	
EndFunction

Procedure ImportedSchemaDefaultDCSettings(ReportObject, ImportedSchema, DCSettings, NewDCUserSettings) Export
	
	If Not DCSettings.AdditionalProperties.Property("ReportInitialized") Or (DCSettings.AdditionalProperties.Property("ReportInitialized")
		AND Not DCSettings.AdditionalProperties.ReportInitialized) Then
		
		DCSchema = ReportObject.DataCompositionSchema;
		
		DCSettings = DCSchema.DefaultSettings;
		DCSettings.AdditionalProperties.Insert("DataCompositionSchema", ImportedSchema);
		DCSettings.AdditionalProperties.Insert("ReportInitialized",  True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with the data source of a report option.

// Sets the DataSource parameter of report option settings
//
// Parameters:
//  Option - CatalogRef.ReportsOptions - a report option settings storage.
//
Procedure DetermineOptionDataSource(Option) Export
	UniversalReport = Common.MetadataObjectID(Metadata.Reports.UniversalReport);
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add(Option.Metadata().FullName());
		LockItem.SetValue("Ref", Option);
		Lock.Lock();
		
		OptionObject = Option.GetObject();
		
		OptionSettings = Undefined;
		If OptionObject <> Undefined
			AND OptionObject.Report = UniversalReport Then 
			OptionSettings = OptionSettings(OptionObject);
		EndIf;
		
		If OptionSettings = Undefined Then 
			RollbackTransaction();
			InfobaseUpdate.MarkProcessingCompletion(Option);
			Return;
		EndIf;
		
		OptionObject.Settings = New ValueStorage(OptionSettings);
		InfobaseUpdate.WriteData(OptionObject);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

// Returns the report option settings with the set DataSource parameter.
//
// Parameters:
//  Option - CatalogObject.ReportOptions - a report option settings storage.
//
// Returns:
//   DataCompositionSettings, Undefined - updated setting or Undefined if update failed.
//                                            
//
Function OptionSettings(Option)
	Try
		OptionSettings = Option.Settings.Get();
	Except
		// Cannot deserialize the value storage, for example, because of the reference to a non-existing type.
		Return Undefined;
	EndTry;
	
	If OptionSettings = Undefined Then 
		Return Undefined;
	EndIf;
	
	DataParameters = OptionSettings.DataParameters.Items;
	
	ParametersRequired = New Structure(
		"MetadataObjectType, FullMetadataObjectName, MetadataObjectName, DataSource");
	For Each Parameter In ParametersRequired Do 
		FoundParameter = DataParameters.Find(Parameter.Key);
		If FoundParameter <> Undefined Then 
			ParametersRequired[Parameter.Key] = FoundParameter.Value;
		EndIf;
	EndDo;
	
	// If option settings contain a parameter with a non-relevant name, the name will be updated.
	If ValueIsFilled(ParametersRequired.FullMetadataObjectName) Then 
		ParametersRequired.MetadataObjectName = ParametersRequired.FullMetadataObjectName;
	EndIf;
	ParametersRequired.Delete("FullMetadataObjectName");
	
	If Not ValueIsFilled(ParametersRequired.DataSource) Then 
		ParametersRequired.DataSource = DataSource(
			ParametersRequired.MetadataObjectType, ParametersRequired.MetadataObjectName);
		If ParametersRequired.DataSource = Undefined Then 
			Return Undefined;
		EndIf;
	EndIf;
	
	ParametersToSet = New Structure("DataSource, MetadataObjectName");
	FillPropertyValues(ParametersToSet, ParametersRequired);
	
	ObjectName = Common.ObjectAttributeValue(ParametersRequired.DataSource, "Name");
	If ObjectName <> ParametersToSet.MetadataObjectName Then 
		ParametersToSet.MetadataObjectName = ObjectName;
	EndIf;
	
	For Each Parameter In ParametersToSet Do 
		FoundParameter = DataParameters.Find(Parameter.Key);
		If FoundParameter = Undefined Then 
			DataParameter = DataParameters.Add();
			DataParameter.Parameter = New DataCompositionParameter(Parameter.Key);
			DataParameter.Value = Parameter.Value;
			DataParameter.Use = True;
			
			If Parameter.Key = "MetadataObjectName"
				AND Not ValueIsFilled(DataParameter.UserSettingID) Then 
				DataParameter.UserSettingID = New UUID;
				DataParameter.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
			EndIf;
		Else
			OptionSettings.DataParameters.SetParameterValue(Parameter.Key, Parameter.Value);
		EndIf;
	EndDo;
	
	Return OptionSettings;
EndFunction

// Returns report data source
//
// Parameters:
//  ManagerType - String - a metadata object manager presentation, for example, "Catalogs" or 
//                 "InformationRegisters" and other presentations.
//  ObjectName  - String - a short name of a metadata object, for example, "Currencies" or 
//                "ExchangeRates", and so on.
//
// Returns:
//   CatalogRef.MetadataObjectsIDs, Undefined - a reference to the found item of the catalog, 
//   otherwise - Undefined.
//
Function DataSource(ManagerType, ObjectName)
	ObjectType = ObjectTypeByManagerType(ManagerType);
	FullObjectName = ObjectType + "." + ObjectName;
	If Metadata.FindByFullName(FullObjectName) = Undefined Then 
		Return Undefined;
	EndIf;
	
	Return Common.MetadataObjectID(FullObjectName);
EndFunction

// Returns the type of metadata object by the matching manager type
//
// Parameters:
//  ManagerType - String - a metadata object manager presentation, for example, "Catalogs" or 
//                 "InformationRegisters" and other presentations.
//
// Returns:
//   String - a metadata object type, for example, "Catalog" or "InformationRegister", and so on.
//
Function ObjectTypeByManagerType(ManagerType)
	Types = New Map;
	Types.Insert("Catalogs", "Catalog");
	Types.Insert("Documents", "Document");
	Types.Insert("DataProcessors", "DataProcessor");
	Types.Insert("ChartsOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	Types.Insert("AccountingRegisters", "AccountingRegister");
	Types.Insert("AccumulationRegisters", "AccumulationRegister");
	Types.Insert("CalculationRegisters", "CalculationRegister");
	Types.Insert("InformationRegisters", "InformationRegister");
	Types.Insert("BusinessProcesses", "BusinessProcess");
	Types.Insert("DocumentJournals", "DocumentJournal");
	Types.Insert("Tasks", "Task");
	Types.Insert("Reports", "Report");
	Types.Insert("Constants", "Constant");
	Types.Insert("Enums", "Enum");
	Types.Insert("ChartsOfCalculationTypes", "ChartOfCalculationTypes");
	Types.Insert("ExchangePlans", "ExchangePlan");
	Types.Insert("ChartsOfAccounts", "ChartOfAccounts");
	
	Return ?(Types[ManagerType] = Undefined, "", Types[ManagerType]);
EndFunction

#EndRegion

#EndIf