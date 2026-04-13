{% macro multiply(x,y,precision)%}
round({{x}}*{{y}},2)
{%endmacro%}