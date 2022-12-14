#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function CheckApplicableDocuments(DocumentRef, Company, Period) Export

	If Not Constants.AccountingModuleSettings.UseTemplatesIsEnabled() Then
		Return New Array;
	EndIf;
	
	TypesOfAccountingTable = AccountingTemplatesPosting.GetApplicableTypesOfAccounting(
		Company, 
		Period, 
		Catalogs.TypesOfAccounting.EmptyRef(),
		,
		True);
		
	AccountingRegistersArray = AccountingTemplatesPosting.GetValuesArrayFromTable(TypesOfAccountingTable, "ChartOfAccountsID");
		
	IsRecorder						= False;
	TypesOfAccountingWithRecorder	= New Array;
	DocRefMetadata					= DocumentRef.Metadata();
	MetadataRegisterRecords			= DocRefMetadata.RegisterRecords;
	
	For Each RegisterID In AccountingRegistersArray Do
		
		ChartOfAccountName = AccountingApprovalServer.GetChartOfAccountsName(RegisterID);
		
		If ValueIsFilled(ChartOfAccountName) Then
			ChartOfAccountMetadata = Metadata.ChartsOfAccounts[ChartOfAccountName];
		Else
			Continue;
		EndIf;
		
		For Each Register In Metadata.AccountingRegisters Do
			
			If Register.ChartOfAccounts <> ChartOfAccountMetadata Then
				Continue;
			EndIf;
				
			If MetadataRegisterRecords.Contains(Register) Then
				
				IsRecorder = True;
				
				Filter = New Structure("ChartOfAccountsID", RegisterID);
				TypeOfAccountingRows = TypesOfAccountingTable.FindRows(Filter);
				
				For Each TypeOfAccountingRow In TypeOfAccountingRows Do
					TypesOfAccountingWithRecorder.Add(TypeOfAccountingRow.TypeOfAccounting);
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If Not IsRecorder Then
		Return New Array;
	EndIf;
	
	TypesOfAccountingWithRecorder = CommonClientServer.CollapseArray(TypesOfAccountingWithRecorder);
	
	DocumentType = Common.MetadataObjectID(DocRefMetadata);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingSourceDocumentsSliceLast.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	InformationRegister.AccountingSourceDocuments.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND DocumentType = &DocumentType
	|				AND TypeOfAccounting IN (&TypeOfAccountingList)) AS AccountingSourceDocumentsSliceLast";
	
	Query.SetParameter("Company"				, Company);
	Query.SetParameter("DocumentType"			, DocumentType);
	Query.SetParameter("Period"					, Period);
	Query.SetParameter("TypeOfAccountingList"	, TypesOfAccountingWithRecorder);
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();

	While SelectionDetailRecords.Next() Do
		
		Index = TypesOfAccountingWithRecorder.Find(SelectionDetailRecords.TypeOfAccounting);
		
		If Index <> Undefined Then
			TypesOfAccountingWithRecorder.Delete(Index);
		EndIf;
		
	EndDo;
	
	Return TypesOfAccountingWithRecorder;

EndFunction

Procedure CheckNotifyTypesOfAccountingProblems(DocumentRef, Company, Period, Cancel = Undefined) Export

	TypesOfAccountingErrors = CheckApplicableDocuments(DocumentRef, Company, Period);
	
	If TypesOfAccountingErrors.Count() = 0 Then
		Return;
	EndIf;
	
	TypesString = "";
	FirstItem = True;
	For Each ProblemType In TypesOfAccountingErrors Do
		If FirstItem Then
			TypesString = TypesString + ProblemType;
			FirstItem = False;
		Else
			TypesString = TypesString + ", " + ProblemType;
		EndIf;
	EndDo;
	
	MessageTmpl = NStr("en = 'Company %1 on date %2 have no Accounting source documents list for %3.
		|Go to ""Company -> Accounting source documents"" and add an Accounting source documents item applicable on %2.'; 
		|ru = '?????????????????????? %1 ???? %2 ???? ?????????? ???????????? ?????????????????? ?????????????????????????? ???????????????????? ?????? %3.
		|?????????????????? ?? ???????? ""?????????????????????? -> ?????????????????? ?????????????????? ???????????????????????????? ??????????"" ?? ???????????????? ?????????????????? ?????????????????? ???????????????????????????? ??????????, ???????????????????? ???? %2.';
		|pl = 'Firma %1 na dzie?? %2 nie ma listy ??r??d??owych dokument??w ksi??gowych dla %3.
		|Przejd?? do ""Firma -> ??r??d??owe dokumenty ksi??gowe"" i dodaj pozycj?? ??r??d??owych dokument??w ksi??gowych zastosowanych na %2.';
		|es_ES = 'La empresa %1 en la fecha %2 no tiene una lista de documentos de fuente contable para %3. 
		|Vaya a ""Empresa -> Documentos de fuente de contabilidad"" y a??ada un art??culo de documentos de fuente de contabilidad aplicable en %2.';
		|es_CO = 'La empresa %1 en la fecha %2 no tiene una lista de documentos de fuente contable para %3. 
		|Vaya a ""Empresa -> Documentos de fuente de contabilidad"" y a??ada un art??culo de documentos de fuente de contabilidad aplicable en %2.';
		|tr = '%1 i?? yerinin %2 tarihinde %3 i??in hi?? Muhasebe kaynak belgesi listesi yok.
		|""???? yeri -> Muhasebe kaynak belgeleri"" b??l??m??ne gidip %2''de uygulanabilecek Muhasebe kaynak belgeleri ????esi ekleyin.';
		|it = 'L''azienda %1 in data %2 non ha un elenco di documenti fonte di contabilit?? per %3.
		|Andare in ""Azienda -> Documenti fonte di contabilit??"" e aggiungere un elemento di documenti fonte di contabilit?? applicabile a %2.';
		|de = 'Firma %1 hat am Datum %2 keine Buchhaltungsquelldokumentenliste f??r %3.
		|Gehen Sie zu ""Firma-> Buchhaltungsquelldokumente"" und f??gen ein Element von Buchhaltungsquelldokumente, das f??r %2 verwendet ist, hinzu.'");
	MessageText = StrTemplate(MessageTmpl, Company, Format(Period, "DLF=D"), TypesString);
	
	If Cancel = Undefined Then
		Raise MessageText;
	Else
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;

EndProcedure

#EndRegion

#EndIf