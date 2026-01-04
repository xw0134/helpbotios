package com.example.HelpBot.utils;

public class ValuePair<F, S>
{
    public final F first;
    public final S second;

    public ValuePair(final F first, final S second) {
        super();
        this.first = first;
        this.second = second;
    }

    public static <F, S> ValuePair<F, S> from(final F first, final S second) {
        return new ValuePair<F, S>(first, second);
    }
}