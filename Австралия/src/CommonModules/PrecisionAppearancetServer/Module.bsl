
#Region Public

// Returns company precision.
//
Function CompanyPrecision(Company) Export
	
	Precision = 2;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.PricesPrecision AS PricesPrecision
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.DeletionMark
	|	AND Companies.Ref = &Company";
	
	Query.SetParameter("Company", Company);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Precision = Selection.PricesPrecision;
	EndIf;
	
	Return Precision;
	
EndFunction

// Returns maximum precision in companies.
//
Function MaxCompanyPrecision() Export
	
	Precision = 2;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	MAX(Companies.PricesPrecision) AS PricesPrecision
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.DeletionMark";
	
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Precision = Selection.PricesPrecision;
	EndIf;
	
	Return Precision;
	
EndFunction

#EndRegion

