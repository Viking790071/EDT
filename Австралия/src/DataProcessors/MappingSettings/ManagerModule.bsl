#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Function TranslationTemplateSettings(TransformationTemplate) Export
	
	Query = New Query("
	|SELECT
	|	Templates.SourceChartOfAccounts AS SourceChartOfAccounts,
	|	SourceChartOfAccountsRef.Synonym AS DescriptionSourceChartOfAccounts,
	|	SourceChartOfAccountsRef.Name AS NameSourceChartOfAccounts,
	|	Templates.ReceivingChartOfAccounts AS ReceivingChartOfAccounts,
	|	ReceivingChartOfAccountsRef.Synonym AS DescriptionReceivingChartOfAccounts,
	|	ReceivingChartOfAccountsRef.Name AS NameReceiverChartOfAccounts,
	|	Templates.SourceAccountingRegister AS SourceAccountingRegister,
	|	Templates.ReceivingAccountingRegister AS ReceivingAccountingRegister
	|FROM
	|	Catalog.TransformationTemplates AS Templates
	|
	|	LEFT JOIN Catalog.MetadataObjectIDs AS SourceChartOfAccountsRef
	|	ON SourceChartOfAccountsRef.Ref = Templates.SourceChartOfAccounts
	|
	|	LEFT JOIN Catalog.MetadataObjectIDs AS ReceivingChartOfAccountsRef
	|	ON ReceivingChartOfAccountsRef.Ref = Templates.ReceivingChartOfAccounts
	|
	|WHERE
	|	Templates.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", TransformationTemplate);
	
	Selection = Query.Execute().Select();
	
	Selection.Next();
	
	TemplateFields = New Structure();
	TemplateFields.Insert("SourceChartOfAccounts"      , Selection.SourceChartOfAccounts);
	TemplateFields.Insert("ReceivingChartOfAccounts"   , Selection.ReceivingChartOfAccounts);
	TemplateFields.Insert("SourceAccountingRegister"   , Selection.SourceAccountingRegister);
	TemplateFields.Insert("ReceivingAccountingRegister", Selection.ReceivingAccountingRegister);
	TemplateFields.Insert("NameSourceChartOfAccounts"  , Selection.NameSourceChartOfAccounts);
	TemplateFields.Insert("NameReceiverChartOfAccounts", Selection.NameReceiverChartOfAccounts);
	TemplateFields.Insert("DescriptionSourceChartOfAccounts"   , Selection.DescriptionSourceChartOfAccounts);
	TemplateFields.Insert("DescriptionReceivingChartOfAccounts", Selection.DescriptionReceivingChartOfAccounts);
	
	Query = New Query("
	|SELECT
	|	MAX(GLMapping.MappingID) AS MappingID
	|FROM
	|	Catalog.Mapping AS GLMapping
	|WHERE
	|	GLMapping.Owner = &Owner
	|");
	
	Query.SetParameter("Owner", TransformationTemplate);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		TemplateFields.Insert("MappingID", Selection.MappingID);
	Else
		TemplateFields.Insert("MappingID", 0);
	EndIf;
	
	Return TemplateFields;
	
EndFunction

#EndRegion

#EndIf